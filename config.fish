if status is-interactive
    # Open the general Fish alias config in VS Code.
    abbr -a cf 'code /Users/hsi/.config/fish/aliases.fish'

    # Open the Git-focused Fish alias config in VS Code.
    abbr -a cfg 'code /Users/hsi/.config/fish/git-aliases.fish'

    # Kill Bun dev server processes started with either command form.
    abbr -a debun 'pkill -f "bun dev"; pkill -f "bun run dev"'

    function prmedia-onboard --description 'Create PR media access for a friend'
        if test (count $argv) -ne 1
            echo 'usage: prmedia-onboard name' >&2
            return 1
        end

        set -l name $argv[1]
        if not string match -qr '^[a-z0-9][a-z0-9_-]{0,31}$' -- "$name"
            echo 'prmedia-onboard: name must use lowercase letters, numbers, underscores, or hyphens' >&2
            return 1
        end

        set -l setup_dir "$HOME/Downloads"
        set -l setup_path "$setup_dir/pr-media-setup-$name.sh"

        if test -e "$setup_path"
            echo "prmedia-onboard: refusing to overwrite $setup_path" >&2
            return 1
        end

        command mkdir -p "$setup_dir"; or return

        set -l token_output (
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token create "$name"
        )
        set -l ssh_status $status
        if test $ssh_status -ne 0
            return $ssh_status
        end

        set -l url_lines (string match 'url=*' -- $token_output)
        set -l token_lines (string match 'token=*' -- $token_output)
        if test (count $url_lines) -ne 1; or test (count $token_lines) -ne 1
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia-onboard: unexpected token response; revoked the new token' >&2
            return 1
        end

        set -l media_url (string replace 'url=' '' -- $url_lines[1])
        set -l media_token (string replace 'token=' '' -- $token_lines[1])
        if not string match -qr '^https://[A-Za-z0-9.-]+/?$' -- "$media_url"; or \
                not string match -qr '^[A-Za-z0-9_-]{32,}$' -- "$media_token"
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia-onboard: invalid token response; revoked the new token' >&2
            return 1
        end

        set -l setup_temp (command mktemp "$setup_dir/.pr-media-setup-$name.XXXXXX")
        if test $status -ne 0
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia-onboard: could not create setup script; revoked the new token' >&2
            return 1
        end

        begin
            printf '%s\n' \
                '#!/usr/bin/env bash' \
                'set -euo pipefail' \
                '' \
                'umask 077' \
                'config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pr-media"' \
                'config_path="$config_dir/config"' \
                '' \
                'if [[ -e "$config_path" ]]; then' \
                '  printf "Refusing to overwrite existing config: %s\n" "$config_path" >&2' \
                '  exit 1' \
                'fi' \
                '' \
                'mkdir -p "$config_dir"' \
                'temporary="$(mktemp "$config_dir/.config.XXXXXX")"' \
                'trap '\''rm -f -- "$temporary"'\'' EXIT' \
                "printf '%s\\n' 'url=$media_url' 'token=$media_token' >\"\$temporary\"" \
                'chmod 600 "$temporary"' \
                'mv "$temporary" "$config_path"' \
                'trap - EXIT' \
                '' \
                'printf "Installed private PR-media credentials at %s\n" "$config_path"' \
                'helper="${CODEX_HOME:-$HOME/.codex}/skills/pr/scripts/pr-media-upload"' \
                'if [[ -x "$helper" ]] && "$helper" --available; then' \
                '  printf "Verified the PR media uploader.\n"' \
                'else' \
                '  printf "\nNext, ask Codex: Install the skills from Hsiii/human-out-of-loop\n"' \
                'fi' \
                'printf "\nDelete this setup script now; it contains your access token.\n"'
        end >"$setup_temp"

        if test $status -ne 0; or \
                not command chmod 700 "$setup_temp"; or \
                not command ln "$setup_temp" "$setup_path"
            command rm -f "$setup_temp"
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia-onboard: could not create setup script; revoked the new token' >&2
            return 1
        end

        if not command rm -f "$setup_temp"
            command rm -f "$setup_path"
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia-onboard: could not finalize setup script; revoked the new token' >&2
            return 1
        end

        printf '%s\n' $token_output
        printf '\nSetup script: %s\n' "$setup_path"
        printf 'Send it securely. Your friend runs: bash %s\n' (basename "$setup_path")
        printf 'The script contains the token, so both of you should delete it after setup.\n'
    end

    function prmedia-revoke --description 'Revoke PR media access'
        if test (count $argv) -ne 1
            echo 'usage: prmedia-revoke name' >&2
            return 1
        end

        set -l name $argv[1]
        if not string match -qr '^[a-z0-9][a-z0-9_-]{0,31}$' -- "$name"
            echo 'prmedia-revoke: name must use lowercase letters, numbers, underscores, or hyphens' >&2
            return 1
        end

        command ssh sago-cloud \
            /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name"
    end

    function trycf --description 'Expose the current project with Cloudflare Tunnel'
        set -l port 3000
        set -l project_name (basename (pwd))

        if test (count $argv) -gt 2
            echo 'usage: trycf [port] [project-name]' >&2
            return 1
        end

        if test (count $argv) -ge 1
            set port $argv[1]
        end

        if test (count $argv) -ge 2
            set project_name $argv[2]
        end

        if not string match -qr '^[0-9]+$' -- "$port"
            echo "trycf: port must be numeric, got '$port'" >&2
            return 1
        end

        set -l slug (
            string lower -- "$project_name" |
                string replace -ar '[^a-z0-9]+' '-' |
                string replace -ar '(^-|-$)' ''
        )

        if test -z "$slug"
            echo "trycf: project name '$project_name' does not produce a usable slug" >&2
            return 1
        end

        if not type -q cloudflared
            echo 'trycf: cloudflared is not installed. Install it with: brew install cloudflared' >&2
            return 127
        end

        set -l origin "http://localhost:$port"
        set -l dev_base 'https://dev.hsichen.dev'
        if set -q TRYCF_DEV_BASE
            set dev_base (string trim --right --chars=/ -- "$TRYCF_DEV_BASE")
        end

        set -l dev_url "$dev_base/$slug"
        set -l registered 0

        echo "trycf: forwarding $origin"
        echo "trycf: project slug $slug"
        echo "trycf: dev alias $dev_url"

        if not set -q TRYCF_REGISTER_URL
            echo 'trycf: no TRYCF_REGISTER_URL set; printing the random trycloudflare.com URL only.'
        end

        command cloudflared tunnel --url "$origin" 2>&1 | while read -l line
            echo $line

            if test "$registered" -eq 1
                continue
            end

            set -l quick_url (string match -r 'https://[A-Za-z0-9-]+\.trycloudflare\.com' -- "$line")
            if test -z "$quick_url"
                continue
            end

            set registered 1
            echo "trycf: quick URL $quick_url"

            if type -q pbcopy
                printf '%s\n' "$quick_url" | pbcopy
                echo 'trycf: copied quick URL to clipboard'
            end

            if not set -q TRYCF_REGISTER_URL
                continue
            end

            set -l payload (
                printf '{"project":"%s","target":"%s","origin":"%s"}' \
                    "$slug" "$quick_url" "$origin"
            )
            set -l curl_args -fsS -X POST -H 'Content-Type: application/json'

            if set -q TRYCF_REGISTER_TOKEN
                set curl_args $curl_args -H "Authorization: Bearer $TRYCF_REGISTER_TOKEN"
            end

            set curl_args $curl_args --data "$payload" "$TRYCF_REGISTER_URL"

            if command curl $curl_args >/dev/null
                echo "trycf: registered $dev_url -> $quick_url"
                if type -q pbcopy
                    printf '%s\n' "$dev_url" | pbcopy
                    echo 'trycf: copied dev alias to clipboard'
                end
            else
                echo "trycf: failed to register $dev_url" >&2
            end
        end
    end

    function setcur --description 'Create or update a Projects/Current symlink by project folder name'
        set -l projects_root /Users/hsi/Projects
        set -l current_root $projects_root/Current

        if test (count $argv) -ne 1
            echo 'usage: setcur "Project folder Name"' >&2
            return 1
        end

        set -l project_name $argv[1]
        set -l target

        if test -d "$project_name"
            set target (realpath "$project_name")
        else
            set -l matches (
                command find "$projects_root" \
                    -path "$current_root" -prune -o \
                    -path '*/.git' -prune -o \
                    -type d -name "$project_name" -print | sort
            )

            if test (count $matches) -eq 0
                echo "setcur: no project folder named '$project_name' under $projects_root" >&2
                return 1
            end

            if test (count $matches) -gt 1
                echo "setcur: multiple project folders named '$project_name':" >&2
                printf '  %s\n' $matches >&2
                return 1
            end

            set target $matches[1]
        end

        mkdir -p "$current_root"

        set -l link "$current_root/"(basename "$target")
        if test -e "$link"; and not test -L "$link"
            echo "setcur: refusing to replace non-symlink $link" >&2
            return 1
        end

        if test -L "$link"
            rm "$link"
        end

        ln -s "$target" "$link"
        echo "$link -> $target"
    end

    function decur --description 'Remove a Projects/Current symlink by project folder name'
        set -l current_root /Users/hsi/Projects/Current

        if test (count $argv) -ne 1
            echo 'usage: decur "Project folder Name"' >&2
            return 1
        end

        set -l project_name (basename "$argv[1]")
        set -l link "$current_root/$project_name"

        if test -L "$link"
            rm "$link"
            echo "removed $link"
            return 0
        end

        if test -e "$link"
            echo "decur: refusing to remove non-symlink $link" >&2
        else
            echo "decur: no current project symlink named '$project_name' at $link" >&2
        end

        return 1
    end

    function lscur --description 'List Projects/Current symlinks'
        set -l current_root /Users/hsi/Projects/Current

        if test (count $argv) -ne 0
            echo 'usage: lscur' >&2
            return 1
        end

        if not test -d "$current_root"
            echo "lscur: no current project symlinks at $current_root"
            return 0
        end

        set -l links (command find "$current_root" -mindepth 1 -maxdepth 1 -type l -print | sort)
        if test (count $links) -eq 0
            echo "lscur: no current project symlinks at $current_root"
            return 0
        end

        for link in $links
            echo (basename "$link")" -> "(readlink "$link")
        end
    end
end
