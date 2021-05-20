using Yao, YaoBlocksQobj
using Test

@testset "YaoBlocksQobj.jl" begin
    qc = chain(
        3,
        put(1 => X),
        put(2 => Y),
        put(3 => Z),
        put(2 => T),
        swap(1, 2),
        put(3 => Ry(0.7)),
        control(2, 1 => Y),
        control(3, 2 => Z),
    )
    qc1 = chain(3, put(3 => Rx(0.7)), control(2, 1 => Y), control(3, 2 => Z))

    header = Dict("description" => "test circuits")
    exp_header = [Dict("description" => "1"), Dict("description" => "2")]

    circuits = [qc, qc1]
    q = convert_to_qobj(circuits, id = "test", header = header, exp_header = exp_header)

    experiments = q.experiments
    for i = 1:length(experiments)
        exp = experiments[i]
        @test exp isa YaoBlocksQobj.Schema.Experiment
        @test exp.header == Dict("description" => "$i")
        @test exp.config === nothing
        inst = exp.instructions
        ir = convert_to_qbir(inst)
        @test ir == circuits[i]
    end

end
