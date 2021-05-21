using IBMQClient, Yao, YaoBlocksQobj
using Test

@testset "YaoBlocksQobj.jl" begin
    qc = chain(
        3,
        put(1 => X),
        put(2 => Y),
        put(3 => Z),
        put(2 => T),
        put(2 => I2),
        swap(1, 2),
        put(3 => Ry(0.7)),
        control(2, 1 => Y),
        control(3, 2 => Z),
    )
    qc1 = chain(
        3,
        put(1 => H),
        put(3 => Rx(0.7)),
        control(2, 1 => Y),
        control(3, 2 => Z),
        put(1 => Yao.Measure(1)),
    )

    header = Dict("description" => "test circuits")
    exp_header = [Dict("description" => "1"), Dict("description" => "2")]
    circuits = [qc, qc1]

    q = convert_to_qobj(circuits, id = "test", header = header, exp_header = exp_header)
    q1 = convert_to_qobj(circuits)
    q2 = convert_to_qobj(circuits, exp_header = exp_header)

    set = [q, q1, q2]
    for i in set
        experiments = i.experiments
        for i = 1:length(experiments)
            exp = experiments[i]
            @test exp isa YaoBlocksQobj.Schema.Experiment
            @test exp.header == Dict("description" => "$i") || exp.header === nothing
            @test exp.config === nothing
            inst = exp.instructions
            ir = convert_to_qbir(inst)
            @test ir == circuits[i]
        end

        qc_inst = chain(
            1,
            put(1 => YaoBlocksQobj.U1{Float64}(2)),
            put(1 => YaoBlocksQobj.U2{Float64}(1, 0.7)),
            put(1 => YaoBlocksQobj.U3{Float64}(0, 1, 0.7)),
        )

        inst = [
            IBMQClient.Schema.Gate("u1", [0], [2], nothing, nothing),
            IBMQClient.Schema.Gate("u2", [0], [1, 0.7], nothing, nothing),
            IBMQClient.Schema.Gate("u3", [0], [0, 1, 0.7], nothing, nothing),
        ]

        @test qc_inst == convert_to_qbir(inst)
    end

    @testset "qbir misc." begin
        @test YaoBlocksQobj.mat(Number, YaoBlocksQobj.U1(0.7)) ≈ Number[
            1 0
            0 exp(im * 0.7)
        ]

        @test YaoBlocksQobj.mat(Number, YaoBlocksQobj.U2(0.7, 0.5)) ≈ Number[
            1/√2 (-exp(im * 0.5))/√2
            (exp(im * 0.7))/√2 (exp(im * (1.2)))/√2
        ]

        @test YaoBlocksQobj.mat(Number, YaoBlocksQobj.U3(0.7, 0.5, 0.2)) ≈ Number[
            cos(0.7 / 2) -sin(0.7 / 2)*exp(im * 0.2)
            sin(0.7 / 2)*exp(im * 0.5) cos(0.7 / 2)*exp(im * (0.7))
        ]

        @test YaoBlocksQobj.iparams_eltype(YaoBlocksQobj.U1(0.7)) == Float64
        @test YaoBlocksQobj.iparams_eltype(YaoBlocksQobj.U2(0.7, 0.5)) == Float64
        @test YaoBlocksQobj.iparams_eltype(YaoBlocksQobj.U3(0.7, 0.5, 0.2)) == Float64

        @test YaoBlocksQobj.getiparams(YaoBlocksQobj.U1(0.7)) == (0.7)
        @test YaoBlocksQobj.getiparams(YaoBlocksQobj.U2(0.7, 0.5)) == (0.7, 0.5)
        @test YaoBlocksQobj.getiparams(YaoBlocksQobj.U3(0.7, 0.5, 0.2)) == (0.7, 0.5, 0.2)
    end
end
