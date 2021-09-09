using Documenter
using Mercury

makedocs(
    sitename = "Mercury.jl",
    format = Documenter.HTML(prettyurls = false),
    pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/RoboticExplorationLab/Mercury.jl.git",
    devbranch = "main"
)