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
    repo = https://github.com/RoboticExplorationLab/Mercury.jl.git,
    devbranch = "main"
)