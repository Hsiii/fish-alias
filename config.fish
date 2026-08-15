if status is-interactive
    # Kill Bun dev server processes started with either command form.
    function debun --description 'Stop all Bun dev servers'
        set -l pids (command pgrep -f '(^|[ /])bun( run)? dev([[:space:]]|$)')
        set -l search_status $status

        if test $search_status -eq 1
            echo 'debun: no Bun dev servers found'
            return 0
        else if test $search_status -ne 0
            return $search_status
        end

        for pid in $pids
            command ps -p $pid -o pid= -o command=
        end
        command kill $pids
    end

    # Deploy the current project with Bun.
    abbr -a dp 'git switch --ignore-other-worktrees main; and git pull --ff-only; and bun run deploy'

    function forward --description 'Expose the current project with Cloudflare Tunnel'
        set -l port 3000
        set -l project_name (basename (pwd))

        set -l git_common_dir (command git rev-parse --git-common-dir 2>/dev/null)
        if test $status -eq 0
            set git_common_dir (path resolve "$git_common_dir")
            if test (path basename "$git_common_dir") = .git
                set project_name (path basename (path dirname "$git_common_dir"))
            end
        end

        if test (count $argv) -gt 1
            echo 'usage: forward [port]' >&2
            return 1
        end

        if test (count $argv) -ge 1
            set port $argv[1]
        end

        if not string match -qr '^[0-9]+$' -- "$port"
            echo "forward: port must be numeric, got '$port'" >&2
            return 1
        end

        set -l slug (
            string lower -- "$project_name" |
                string replace -ar '[^a-z0-9]+' '-' |
                string replace -ar '(^-|-$)' ''
        )

        if test -z "$slug"
            echo "forward: project name '$project_name' does not produce a usable slug" >&2
            return 1
        end

        if not type -q cloudflared
            echo 'forward: cloudflared is not installed. Install it with: brew install cloudflared' >&2
            return 127
        end

        set -l origin "http://localhost:$port"
        set -l announced 0

        echo "forward: forwarding $origin"
        echo "forward: project slug $slug"

        command cloudflared tunnel --url "$origin" 2>&1 | while read -l line
            echo $line

            if test "$announced" -eq 1
                continue
            end

            set -l quick_url (string match -r 'https://[A-Za-z0-9-]+\.trycloudflare\.com' -- "$line")
            if test -z "$quick_url"
                continue
            end

            set announced 1
            echo "forward: quick URL $quick_url"

            if type -q pbcopy
                printf '%s\n' "$quick_url" | pbcopy
                echo 'forward: copied quick URL to clipboard'
            end
        end
    end

end
