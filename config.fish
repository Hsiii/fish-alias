if status is-interactive
    # Kill Bun dev server processes started with either command form.
    abbr -a debun 'pkill -f "bun dev"; pkill -f "bun run dev"'

    # Deploy the current project with Bun.
    abbr -a dp 'bun run deploy'

    # Remove Codex worktrees registered to the current repository.
    function detree
        argparse 'f/force' -- $argv
        or return

        if test (count $argv) -gt 0
            echo 'detree: expected no arguments' >&2
            return 1
        end

        git rev-parse --git-dir >/dev/null 2>&1
        or begin
            echo 'detree: not inside a Git repository' >&2
            return 1
        end

        set -l codex_home ~/.codex
        if set -q CODEX_HOME
            set codex_home $CODEX_HOME
        end
        set -l codex_worktree_root (path resolve $codex_home/worktrees)
        if test -z "$codex_worktree_root"
            echo 'detree: no Codex worktree directory found'
            return 0
        end

        set -l codex_worktrees
        for worktree in (git worktree list --porcelain | string match 'worktree *' | string replace 'worktree ' '')
            if string match -q -- "$codex_worktree_root/*" "$worktree"
                set -a codex_worktrees $worktree
            end
        end

        if test (count $codex_worktrees) -eq 0
            echo 'detree: no Codex worktrees for this repository'
            return 0
        end

        set -l remove_args
        if set -q _flag_force
            set remove_args --force
        end

        set -l failed 0
        for worktree in $codex_worktrees
            echo "detree: removing $worktree"
            git worktree remove $remove_args -- $worktree
            or set failed 1
        end

        if test $failed -ne 0
            if not set -q _flag_force
                echo 'detree: some worktrees were kept; use --force to remove dirty worktrees' >&2
            end
        end

        return $failed
    end

    function __prmedia_add --description 'Create PR media access for a friend'
        if test (count $argv) -ne 1
            echo 'usage: prmedia -a name' >&2
            return 1
        end

        set -l name $argv[1]
        if not string match -qr '^[a-z0-9][a-z0-9_-]{0,31}$' -- "$name"
            echo 'prmedia: name must use lowercase letters, numbers, underscores, or hyphens' >&2
            return 1
        end

        set -l setup_dir "$HOME/Downloads"
        set -l setup_path "$setup_dir/pr-media-setup-$name.sh"

        if test -e "$setup_path"
            echo "prmedia: refusing to overwrite $setup_path" >&2
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
            echo 'prmedia: unexpected token response; revoked the new token' >&2
            return 1
        end

        set -l media_url (string replace 'url=' '' -- $url_lines[1])
        set -l media_token (string replace 'token=' '' -- $token_lines[1])
        if not string match -qr '^https://[A-Za-z0-9.-]+/?$' -- "$media_url"; or \
                not string match -qr '^[A-Za-z0-9_-]{32,}$' -- "$media_token"
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia: invalid token response; revoked the new token' >&2
            return 1
        end

        set -l setup_temp (command mktemp "$setup_dir/.pr-media-setup-$name.XXXXXX")
        if test $status -ne 0
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia: could not create setup script; revoked the new token' >&2
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
            echo 'prmedia: could not create setup script; revoked the new token' >&2
            return 1
        end

        if not command rm -f "$setup_temp"
            command rm -f "$setup_path"
            command ssh sago-cloud \
                /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name" >/dev/null
            echo 'prmedia: could not finalize setup script; revoked the new token' >&2
            return 1
        end

        printf '%s\n' $token_output
        printf '\nManual setup for your friend:\n'
        printf '  mkdir -p ~/.config/pr-media && chmod 700 ~/.config/pr-media\n'
        printf '  vim ~/.config/pr-media/config\n'
        printf '  chmod 600 ~/.config/pr-media/config\n'
        printf 'Paste the url= and token= lines above into that config file.\n'
        printf '\nSetup script: %s\n' "$setup_path"
        printf 'Send it securely. Your friend runs: bash %s\n' (basename "$setup_path")
        printf 'The script contains the token, so both of you should delete it after setup.\n'
    end

    function __prmedia_delete --description 'Revoke PR media access'
        if test (count $argv) -ne 1
            echo 'usage: prmedia -d name' >&2
            return 1
        end

        set -l name $argv[1]
        if not string match -qr '^[a-z0-9][a-z0-9_-]{0,31}$' -- "$name"
            echo 'prmedia: name must use lowercase letters, numbers, underscores, or hyphens' >&2
            return 1
        end

        command ssh sago-cloud \
            /srv/sago-cloud/operations/scripts/pr-media-token revoke "$name"
    end

    function prmedia --description 'Manage PR media access'
        if test (count $argv) -eq 0
            echo 'usage: prmedia -a name | -d name | -l' >&2
            return 1
        end

        switch $argv[1]
            case -a
                if test (count $argv) -ne 2
                    echo 'usage: prmedia -a name' >&2
                    return 1
                end
                __prmedia_add $argv[2]
            case -d
                if test (count $argv) -ne 2
                    echo 'usage: prmedia -d name' >&2
                    return 1
                end
                __prmedia_delete $argv[2]
            case -l
                if test (count $argv) -ne 1
                    echo 'usage: prmedia -l' >&2
                    return 1
                end
                command ssh sago-cloud \
                    /srv/sago-cloud/operations/scripts/pr-media-token list
            case '*'
                echo 'usage: prmedia -a name | -d name | -l' >&2
                return 1
        end
    end

    function media --description 'Upload media for sharing'
        if test (count $argv) -ne 2; or test "$argv[1]" != add
            echo 'usage: media add <path>' >&2
            return 1
        end
        set -l source_path (path resolve $argv[2])
        if not test -f "$source_path"
            echo "media: file not found: $argv[2]" >&2
            return 1
        end

        set -l upload_path "$source_path"
        set -l temporary_directory
        set -l video_limit 536870912
        set -l extension (string lower -- (path extension "$source_path" | string trim --chars=.))
        set -l file_size (command stat -f %z "$source_path" 2>/dev/null)
        if test $status -ne 0
            set file_size (command stat -c %s "$source_path" 2>/dev/null)
        end

        set -l needs_conversion 0
        if contains -- "$extension" mov m4v
            set needs_conversion 1
        else if contains -- "$extension" mp4; and test "$file_size" -gt "$video_limit"
            set needs_conversion 1
        end

        if test $needs_conversion -eq 1
            if not type -q avconvert
                echo 'media: avconvert is required to prepare this video' >&2
                return 127
            end

            set -l temporary_root /tmp
            if set -q TMPDIR
                set temporary_root (string trim --right --chars=/ -- "$TMPDIR")
            end
            set temporary_directory (command mktemp -d "$temporary_root/media-upload.XXXXXX")
            or return
            set upload_path "$temporary_directory/upload.m4v"

            command avconvert \
                --source "$source_path" \
                --preset PresetAppleM4V720pHD \
                --output "$upload_path" \
                --progress
            set -l convert_status $status
            if test $convert_status -ne 0
                command rm -rf -- "$temporary_directory"
                return $convert_status
            end

            set file_size (command stat -f %z "$upload_path" 2>/dev/null)
            if test "$file_size" -gt "$video_limit"
                command rm -f -- "$upload_path"
                command avconvert \
                    --source "$source_path" \
                    --preset Preset960x540 \
                    --output "$upload_path" \
                    --progress
                set convert_status $status
                if test $convert_status -ne 0
                    command rm -rf -- "$temporary_directory"
                    return $convert_status
                end
            end
        end

        set extension (string lower -- (path extension "$upload_path" | string trim --chars=.))
        set -l source_extension "$extension"
        if test "$extension" = m4v
            set extension mp4
        end
        switch $extension
            case gif jpeg jpg mp4 png webm webp
            case '*'
                echo 'media: supported formats are PNG, JPEG, GIF, WebP, MP4, and WebM' >&2
                if test -n "$temporary_directory"
                    command rm -rf -- "$temporary_directory"
                end
                return 1
        end

        set -l upload_id (string lower -- (command uuidgen))
        set -l remote_input_path "/tmp/media-upload-$upload_id.$source_extension"
        set -l remote_path "/tmp/media-upload-$upload_id.$extension"
        command ssh sago-cloud \
            docker exec -i sago-cloud-pr-media-api-api-1 \
            tee "$remote_input_path" <"$upload_path" >/dev/null
        set -l stream_status $status
        if test $stream_status -ne 0
            if test -n "$temporary_directory"
                command rm -rf -- "$temporary_directory"
            end
            return $stream_status
        end

        if test "$source_extension" = m4v
            command ssh sago-cloud \
                docker exec sago-cloud-pr-media-api-api-1 \
                ffmpeg -loglevel error -y \
                -i "$remote_input_path" -c copy -movflags +faststart "$remote_path"
            set -l remux_status $status
            command ssh sago-cloud \
                docker exec sago-cloud-pr-media-api-api-1 \
                rm -f -- "$remote_input_path"
            if test $remux_status -ne 0
                if test -n "$temporary_directory"
                    command rm -rf -- "$temporary_directory"
                end
                return $remux_status
            end
        end

        set -l docker_env -e "PR_MEDIA_MAX_VIDEO_BYTES=$video_limit"
        if test -n "$temporary_directory"
            set -a docker_env -e PR_MEDIA_OPTIMIZE=0
        end
        set -l upload_output (
            command ssh sago-cloud \
                docker exec $docker_env \
                sago-cloud-pr-media-api-api-1 \
                /usr/local/bin/pr-media-upload "$remote_path"
        )
        set -l upload_status $status
        command ssh sago-cloud \
            docker exec sago-cloud-pr-media-api-api-1 \
            rm -f -- "$remote_input_path" "$remote_path"
        if test -n "$temporary_directory"
            command rm -rf -- "$temporary_directory"
        end

        if test $upload_status -eq 0
            set -l media_url (string match -r 'https://[^)]+' -- $upload_output)
            if test -n "$media_url"
                printf '%s\n' "$media_url"
                if type -q pbcopy
                    printf '%s' "$media_url" | pbcopy
                    echo 'media: copied URL to clipboard' >&2
                end
            else
                printf '%s\n' $upload_output
            end
        end
        return $upload_status
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
