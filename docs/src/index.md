# YaoBlocksQobj

[![Build Status](https://github.com/QuantumBFS/YaoBlocksQobj.jl/workflows/CI/badge.svg)](https://github.com/QuantumBFS/YaoBlocksQobj.jl/actions)
[![Coverage](https://codecov.io/gh/QuantumBFS/YaoBlocksQobj.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/QuantumBFS/YaoBlocksQobj.jl)

YaoBlocks interafce for the [IBMQClient](https://github.com/QuantumBFS/IBMQClient.jl) package.

## Usage

1) Create a circuit

```julia
using Yao, YaoBlocksQobj
qc = chain(3, put(1=>X), put(2=>Y) ,put(3=>Z), 
                put(2=>T), swap(1,2), put(3=>Ry(0.7)), 
                control(2, 1=>Y), control(3, 2=>Z))
```

2) Creating headers is optional but if they should be in order for respective experiemnts

```julia
# main header for the job
header = Dict("description"=>"test circuits")

# header for the experiments
exp_header = [Dict("description"=>"1")]
```

3) Creating a Qobj

```julia
q = create_qobj([qc], id = "test_id", header= header, exp_header = exp_header)
```
