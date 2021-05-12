using YaoBlocksQobj, DocThemeIndigo
using Documenter
indigo = DocThemeIndigo.install(YaoBlocksQobj)


makedocs(;
    modules=[YaoBlocksQobj],
    authors="Arsh Sharma <sharmarsh15@gmail.com> and contributors",
    repo="https://github.com/QuantumBFS/YaoBlocksQobj.jl/blob/{commit}{path}#{line}",
    sitename="YaoBlocksQobj.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://QuantumBFS.github.io/YaoBlocksQobj.jl",
        assets=String[indigo, "assets/default.css"],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/QuantumBFS/YaoBlocksQobj.jl",
)
