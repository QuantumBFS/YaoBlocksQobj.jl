using Random

"""
    create_qobj(qc, id, header, nshots, exp_header, exp_config)

    Creates a `Qobj` based on the IBMQClient schema.
    
    - `qc`: An `Array` of `ChainBlock`(circuits that are to be run).
    - `id`(optional): User generated run identifier.
    - `header` (optional): User-defined structure that contains metadata on the job and is not used.
    - `nshots`: Number of times to repeat the experiment (for some simulators this may
    be limited to 1, e.g., a unitary simulator).
    Each unitary gate has an efficient representation in this basis.
    - `exp_header`(optional): Array of User-defined structure that contains metadata on each experiment and
    is not used by the backend. The header will be passed through to the result data structure unchanged. 
    For example, this may contain a fitting parameters for the experiment. In addition, this header can 
    contain a mapping of backend memory and backend qubits to OpenQASM registers. 
    This is because an OpenQASM circuit may contain multiple classical and quantum registers, 
    but Qobj flattens them into a single memory and single set of qubits.
    - `exp_config` (optional): An Array of Configuration structure for user settings that can be different in each
    experiment. These will override the configuration settings of the whole job.
"""
function create_qobj(qc::Array{<:AbstractBlock{N}}; id::String = randstring(), header = nothing, nshots::Int = 1024, exp_header = nothing, exp_config = nothing) where N
    experiments = create_experiment(qc, exp_header, exp_config)
    config = ExpConfig(shots = nshots, memory_slots = length(experiments))
    Qobj(;qobj_id = id, type = "QASM", schema_version = v"1", header, experiments = experiments, config = config)
end

"""
    create_experiment(qc, exp_header, exp_config)

    Returns and experiment type that consits of instructions.

    - `qc`: An `Array` of `ChainBlock`(circuits that are to be run).
    - `exp_header`(optional): Array of User-defined structure that contains metadata on each experiment and
    is not used by the backend. The header will be passed through to the result data structure unchanged. 
    For example, this may contain a fitting parameters for the experiment. In addition, this header can 
    contain a mapping of backend memory and backend qubits to OpenQASM registers. 
    This is because an OpenQASM circuit may contain multiple classical and quantum registers, 
    but Qobj flattens them into a single memory and single set of qubits.
    - `exp_config` (optional): An Array of Configuration structure for user settings that can be different in each
    experiment. These will override the configuration settings of the whole job.
"""
function create_experiment(qc::Array{<:AbstractBlock{N}}, exp_header = nothing, exp_config = nothing) where N
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
            exp = create_experiment!(qc[i], exp_header[i], exp_config[i])
        elseif head && !config
            exp = create_experiment!(qc[i], exp_header[i], exp_config)
        elseif !head && config
            exp = create_experiment!(qc[i], exp_header, exp_config[i])
        else
            exp = create_experiment!(qc[i], exp_header, exp_config)
        end

        push!(experiments, exp)
    end
    return experiments
end

function create_experiment!(qc::AbstractBlock{N}, exp_header = nothing, exp_config = nothing) where N
    exp_inst = generate_inst(qc)
    experiment = Experiment(;header = exp_header, config = exp_config, instructions = exp_inst)
    return experiment
end

"""
    generate_inst(qc)

    Parses the YaoIR into a list of IBMQ supported instructions

    - `qc`: A `ChainBlock`(circuit that is to be run).
"""
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
