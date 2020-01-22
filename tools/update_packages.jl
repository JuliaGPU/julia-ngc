import GitCommand: git
import GitHub

# Some of the code in this file is taken from:
# 1. CompatHelper.jl (https://github.com/bcbi/CompatHelper.jl)
# 2. https://github.com/JuliaRegistries/General/blob/master/.ci/remember_to_update_registryci.jl

struct AlwaysAssertionError <: Exception
    msg::String
end

@inline function always_assert(cond::Bool, msg::String)::Nothing
    cond || throw(AlwaysAssertionError(msg))
    return nothing
end

function get_all_pull_requests(repo::GitHub.Repo,
                               state::String;
                               auth::GitHub.Authorization,
                               per_page::Integer = 100,
                               page_limit::Integer = 100)
    all_pull_requests = Vector{GitHub.PullRequest}(undef, 0)
    myparams = Dict("state" => state,
                    "per_page" => per_page,
                    "page" => 1)
    prs, page_data = GitHub.pull_requests(repo;
                                          auth=auth,
                                          params = myparams,
                                          page_limit = page_limit)
    append!(all_pull_requests, prs)
    while haskey(page_data, "next")
        prs, page_data = GitHub.pull_requests(repo;
                                              auth=auth,
                                              page_limit = page_limit,
                                              start_page = page_data["next"])
        append!(all_pull_requests, prs)
    end
    unique!(all_pull_requests)
    return all_pull_requests
end

_repos_are_the_same(::GitHub.Repo, ::Nothing) = false
_repos_are_the_same(::Nothing, ::GitHub.Repo) = false
_repos_are_the_same(::Nothing, ::Nothing) = false
function _repos_are_the_same(x::GitHub.Repo, y::GitHub.Repo)
    if x.name == y.name && x.full_name == y.full_name &&
                           x.owner == y.owner &&
                           x.id == y.id &&
                           x.url == y.url &&
                           x.html_url == y.html_url &&
                           x.fork == y.fork
       return true
    else
        return false
    end
end

function exclude_pull_requests_from_forks(repo::GitHub.Repo, pr_list::Vector{GitHub.PullRequest})
    non_forked_pull_requests = Vector{GitHub.PullRequest}(undef, 0)
    for pr in pr_list
        always_assert(_repos_are_the_same(repo, pr.base.repo), "_repos_are_the_same(repo, pr.base.repo)")
        if _repos_are_the_same(repo, pr.head.repo)
            push!(non_forked_pull_requests, pr)
        end
    end
    return non_forked_pull_requests
end

function only_my_pull_requests(pr_list::Vector{GitHub.PullRequest}; my_username::String)
    _my_username_lowercase = lowercase(strip(my_username))
    n = length(pr_list)
    pr_is_mine = BitVector(undef, n)
    for i = 1:n
        pr_user_login = pr_list[i].user.login
        if lowercase(strip(pr_user_login)) == _my_username_lowercase
            pr_is_mine[i] = true
        else
            pr_is_mine[i] = false
        end
    end
    my_pr_list = pr_list[pr_is_mine]
    return my_pr_list
end

function git_commit(message)::Bool
    return try
        git() do git
            p = run(`$git commit -m "$(message)"`)
            wait(p)
            success(p)
        end
    catch
        false
    end
end

function generate_username_mentions(usernames::AbstractVector)::String
    intermediate_result = ""
    for username in usernames
        _username = filter(x -> x != '@', strip(username))
        if length(_username) > 0
            intermediate_result = intermediate_result * "\ncc: @$(_username)"
        end
    end
    final_result = convert(String, strip(intermediate_result))
    return final_result
end

function set_git_identity(username, email)
    git() do git
        run(`$git config user.name "$(username)"`)
        run(`$git config user.email "$(email)"`)
    end
    return nothing
end

function with_temp_dir(f::Function)
    original_directory = pwd()
    tmp_dir = mktempdir()
    atexit(() -> rm(tmp_dir; force = true, recursive = true))
    cd(tmp_dir)
    result = f(tmp_dir)
    cd(original_directory)
    rm(tmp_dir; force = true, recursive = true)
    return result
end

function main(main_repo::AbstractString;
              github_token::AbstractString = ENV["GITHUB_TOKEN"],
              cc_usernames::AbstractVector{<:AbstractString} = String[],
              my_username::AbstractString = "github-actions[bot]",
              my_email::AbstractString = "41898282+github-actions[bot]@users.noreply.github.com")
    @info "Update packages"
    update_log = read(`$(Base.julia_cmd()) --project -e "using Pkg; Pkg.update()"`, String)

    # check if something changed
    changed = git() do git
        !success(`$git diff-index --exit-code --ignore-submodules HEAD`)
    end
    changed || return

    username_mentions_text = generate_username_mentions(cc_usernames)
    my_pr_branch_name = "update_packages"
    my_pr_title = "Update packages"
    my_pr_commit_message = my_pr_title

    status_log = read(`$(Base.julia_cmd()) --project -e "using Pkg; Pkg.status(diff=true)"`, String)

    my_pr_body = """
        This pull request updates the following packages:

        ```
        $(status_log)
        ```

        $(username_mentions_text)

        <details><summary>Click here for the update log.</summary>
        <p>

        ```
        $(update_log)
        ```

        </p>
        </details>
        """

    set_git_identity(my_username, my_email)

    auth = try
        GitHub.authenticate(github_token)
    catch
        nothing
    end

    git() do git
        run(`$(git) add -A`)
    end
    commit_was_success = git_commit(my_pr_commit_message)
    @info("commit_was_success: $(commit_was_success)")

    git() do git
        run(`$(git) push --force origin HEAD:$(my_pr_branch_name)`)
    end

    params = Dict{String, String}()
    params["title"] = my_pr_title
    params["head"] = my_pr_branch_name
    params["base"] = "master"
    params["body"] = my_pr_body
    main_repo_github = GitHub.repo(main_repo; auth = auth)
    try
        GitHub.create_pull_request(main_repo_github;
                                    params = params,
                                    auth = auth)
    catch ex
        @error "Could not create pull request" exception=(ex, catch_backtrace())
    end
    _all_prs = get_all_pull_requests(main_repo_github, "open"; auth = auth)
    _all_nonforked_prs = exclude_pull_requests_from_forks(main_repo_github, _all_prs)
    _all_my_prs = only_my_pull_requests(_all_nonforked_prs; my_username = my_username)
    _this_job_pr = Vector{GitHub.PullRequest}(undef, 0)
    for candidate_pr in _all_my_prs
        if candidate_pr.base.ref == params["base"] && candidate_pr.head.ref == params["head"]
            push!(_this_job_pr, candidate_pr)
        end
    end
    for pr in _this_job_pr
        GitHub.update_pull_request(main_repo_github,
                                    pr;
                                    params = params,
                                    auth = auth)
    end

    return
end
