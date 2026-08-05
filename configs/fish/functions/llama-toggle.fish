# llama-toggle.fish — suspend/resume/kill llama-server instances
# Usage:
#   llama-toggle                → show status of known instances
#   llama-toggle --suspend      → SIGSTOP all llama-server procs
#   llama-toggle --resume       → SIGCONT all llama-server procs
#   llama-toggle --kill         → SIGTERM all llama-server procs
#   llama-toggle --stop-model <name>  → stop a specific model by partial match
#   llama-toggle --list                    → show all llama-server procs with args

function llama-toggle --description 'Suspend/resume/kill llama-server instances'
    set -l action status
    set -l model_filter ""

    # parse flags
    for a in $argv
        switch $a
            case --suspend
                set action suspend
            case --resume
                set action resume
            case --kill
                set action kill
            case --stop-model
                set action kill-model
            case --list
                set action list
            case '-*'
                # ignore
            case '*'
                if test "$action" = "kill-model"
                    set model_filter $a
                end
        end
    end

    # discover llama-server PIDs
    set -l pids
    for line in (ps aux | grep 'llama-server' | grep -v grep)
        set pid (echo "$line" | awk '{print $2}')
        if test -n "$pid"
            set pids $pids $pid
        end
    end

    if test (count $pids) -eq 0
        echo "[llama-toggle] no llama-server processes found"
        return 0
    end

    switch $action
        case status
            echo "[llama-toggle] running instances:"
            for pid in $pids
                set cmdline (cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
                # parse port and model without grep -P
                set port ""
                set model ""
                set prev ""
                for tok in (string split ' ' "$cmdline")
                    if test "$prev" = "--port"
                        set port "$tok"
                    else if test "$prev" = "--model"
                        set model (basename "$tok")
                    end
                    set prev "$tok"
                end
                echo "  PID $pid  port=$port  model=$model"
            end
            echo ""
            echo "  suspend:   llama-toggle --suspend"
            echo "  resume:    llama-toggle --resume"
            echo "  kill:      llama-toggle --kill"
            echo "  stop-model llama-toggle --stop-model gemma"
        case suspend
            for pid in $pids
                if test -n "$model_filter"
                    set cmdline (cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
                    if not echo "$cmdline" | grep -qi "$model_filter"
                        continue
                    end
                end
                kill -STOP $pid 2>/dev/null && echo "[llama-toggle] suspended PID $pid"
            end
        case resume
            for pid in $pids
                if test -n "$model_filter"
                    set cmdline (cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
                    if not echo "$cmdline" | grep -qi "$model_filter"
                        continue
                    end
                end
                kill -CONT $pid 2>/dev/null && echo "[llama-toggle] resumed PID $pid"
            end
        case kill
            for pid in $pids
                kill $pid 2>/dev/null && echo "[llama-toggle] killed PID $pid"
            end
        case kill-model
            for pid in $pids
                set cmdline (cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
                if echo "$cmdline" | grep -qi "$model_filter"
                    kill $pid 2>/dev/null && echo "[llama-toggle] killed PID $pid ($model_filter)"
                end
            end
        case list
            for pid in $pids
                set cmdline (cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
                echo "PID $pid: $cmdline"
            end
    end
end
