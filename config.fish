if status is-interactive
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
end
