using Random

function CreateQobj(qc::Array{<:AbstractBlock{N}}; id::String = randstring(), header = nothing, nshots::Int = 1024, exp_header = nothing, exp_config = nothing) where N
    experiments = CreateExperiment(qc, exp_header, exp_config)
    config = ExpConfig(shots = nshots, memory_slots = length(experiments))
    Qobj(;qobj_id = id, type = "QASM", schema_version = v"1", header, experiments = experiments, config = config)
end

function CreateExperiment(qc::Array{<:AbstractBlock{N}}, exp_header = nothing, exp_config = nothing) where N
    experiments = Experiment[]
    head = false
    config = false
    if exp_header !== nothing 
        head = true 
    elseif exp_config !== nothing 
        config = true
    end
    
    for i in 1:length(qc)
        if head && config
            exp = CreateExperiment!(qc[i], exp_header[i], exp_config[i])
        elseif head && !config
            exp = CreateExperiment!(qc[i], exp_header[i], exp_config)
        elseif !head && config
            exp = CreateExperiment!(qc[i], exp_header, exp_config[i])
        else
            exp = CreateExperiment!(qc[i], exp_header, exp_config)
        end

        push!(experiments, exp)
    end
    return experiments
end

function CreateExperiment!(qc::AbstractBlock{N}, exp_header = nothing, exp_config = nothing) where N
    exp_inst = generate_inst(qc)
    experiment = Experiment(;header = exp_header, config = exp_config, instructions = exp_inst)
    return experiment
end

function generate_inst(qc::AbstractBlock{N}) where N
    inst = Instruction[]
    generate_inst!(inst, basicstyle(qc), [0:N-1...], Int[])
    return inst
end

function generate_inst!(inst, qc_simpl::ChainBlock, locs, controls)
    for block in subblocks(qc_simpl)
        generate_inst!(inst, block, locs, controls)
    end
end

function generate_inst!(inst, blk::PutBlock{N,M}, locs, controls) where {N,M}
    generate_inst!(inst, blk.content, sublocs(blk.locs, locs), controls)
end

function generate_inst!(inst, blk::ControlBlock{N,GT,C}, locs, controls) where {N,GT,C}
    any(==(0),blk.ctrl_config) && error("Inverse Control used in Control gate context") 
    generate_inst!(inst, blk.content, sublocs(blk.locs, locs), [controls..., sublocs(blk.ctrl_locs, locs)...])
end

function generate_inst!(inst, m::YaoBlocks.Measure{N}, locs, controls) where N
    # memory:  List of memory slots in which to store the measurement results (mustbe the same length as qubits).  
    mlocs = sublocs(m.locations isa AllLocs ? [1:N...] : [m.locations...], locs)
    (m.operator isa ComputationalBasis) || error("measuring an operator is not supported")
    # (m.postprocess isa NoPostProcess) || error("postprocessing is not supported")
    (length(controls) == 0) || error("controlled measure is not supported")
    push!(inst, Schema.Measure(qubits = mlocs, memory = zeros(length(mlocs))))
end

# IBMQ Chip only supports ["id", "u1", "u2", "u3", "cx"]
# x, y, z and control x, y, z, id, t, swap and other primitive gates
for (GT, NAME, MAXC) in [(:XGate, "x", 2), (:YGate, "y", 2), (:ZGate, "z", 2),
                         (:I2Gate, "id", 0), (:TGate, "t", 0), (:SWAPGate, "swap", 0)]
    @eval function generate_inst!(inst, ::$GT, locs, controls)
        if length(controls) <= $MAXC
            push!(inst, Gate(name = "c"^(length(controls))*$NAME, qubits = [controls..., locs...]))
        else
            error("too many control bits!")
        end
    end
end

# rotation gates
for (GT, NAME, PARAMS, MAXC) in [(:(RotationGate{1, T, XGate} where T), "u3", :([b.theta, -π/2, π/2]), 0),
                           (:(RotationGate{1, T, YGate} where T), "u3", :([b.theta, 0, 0]), 0),
                           (:(RotationGate{1, T, ZGate} where T), "u1", :([b.theta]), 0),
                           (:(ShiftGate), "u1", :([b.theta]), 1),
                           (:(HGate), "u2", :([0, π]), 0),
                          ]
    @eval function generate_inst!(inst, b::$GT, locs, controls)
        if length(controls) <= $MAXC
            push!(inst, Gate(name = "c"^(length(controls))*$NAME, qubits = [controls..., locs...], params = $PARAMS))
        else
            error("too many control bits! got $controls (length > $($(MAXC)))")
        end
    end
end

sublocs(subs, locs) = [locs[i] for i in subs]

function basicstyle(blk::AbstractBlock)
	YaoBlocks.Optimise.simplify(blk, rules=[YaoBlocks.Optimise.to_basictypes])
end
