using Yao, YaoBlocksQobj
using Test

include("qobjtoqbir.jl")

@testset "YaoBlocksQobj.jl" begin
    qc = chain(3, put(1=>X), put(2=>Y) ,put(3=>Z), 
                put(2=>T), swap(1,2), put(3=>Ry(0.7)), 
                control(2, 1=>Y), control(3, 2=>Z))
    exp = CreateExperiment(qc, Dict("description"=>"foo_device"))
    
    
    @test exp isa YaoBlocksQobj.Schema.Experiment
    @test exp.header == Dict("description" => "foo_device")
    @test exp.config == nothing

    inst = exp.instructions
    ir = inst2qbir(inst)
    @test ir == qc
end
