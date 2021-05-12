using YaoBlocksQobj
using Documenter

DocMeta.setdocmeta!(YaoBlocksQobj, :DocTestSetup, :(using YaoBlocksQobj); recursive=true)

makedocs(;
    modules=[YaoBlocksQobj],
    authors="Arsh Sharma",
    repo="https://github.com/QuantumBFS/YaoBlocksQobj.jl/blob/{commit}{path}#{line}",
    sitename="YaoBlocksQobj.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://QuantumBFS.github.io/YaoBlocksQobj.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/QuantumBFS.github.io/YaoBlocksQobj.jl",
)
