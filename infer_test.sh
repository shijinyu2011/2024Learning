current_datetime=$(date +'%Y-%m-%d-%H-%M-%S')
# Default arguments
ARGS_NUM=$#
ARGS_FREQ=1000
ARGS_CYCLE=20
ARGS_DOWN=-100
ARGS_UP=20
ARGS_GOLDEN=0

INFER_TOOL=infer-tool
CNN_FREQ_TOOL=cnnfreq
INFER_TOOL_ARGS=./net.cfg
INFER_TOOL_LOG=/dev/null
LOG_FILE=/dev/null
if [ -z "$INFER_DISPLAY" ]; then
    INFER_DISPLAY=/dev/null
fi

args_index=1
while [ $args_index -le $ARGS_NUM ]
do
    eval arg_value=\$$args_index
    case "$arg_value" in
        "--golden" | "-g") 
            ARGS_GOLDEN=1
            ;;
        "--cycle" | "-c") 
            args_index=$((args_index + 1))
            eval ARGS_CYCLE=\$$args_index
            ;;
        "--down" | "-d") 
            args_index=$((args_index + 1))
            eval ARGS_DOWN=\$$args_index
            ARGS_DOWN=$((ARGS_DOWN * -1))
            ;;
        "--up" | "-u") 
            args_index=$((args_index + 1))
            eval ARGS_UP=\$$args_index
            ;;
        "--log" | "-l")
            args_index=$((args_index + 1))
            eval LOG_FILE=\$$args_index
            ;;
        "--model" | "-m")
            args_index=$((args_index + 1))
            eval MODEL_NAME=\$$args_index
            ;;
        "--display")
            INFER_DISPLAY=/dev/stdout
            ;;
        "--help" | "-h")
            echo "Usage: $0 [--golden] [--cycle CYCLE] [--down DOWN] [--up UP] [--log LOG_FILE] [--model MODEL_NAME] [--display]"
            exit 0
            ;;
        *)
            echo "Invalid argument: $arg_value"
            exit 1
            ;;
    esac
    args_index=$((args_index + 1))
done

if [ $ARGS_GOLDEN -eq 0 ]; then
    echo "|-- Test: $ARGS_FREQ MHz --|" | tee -a $LOG_FILE > $INFER_DISPLAY
    if [ -z "$MODEL_NAME" ]; then
        echo "MODEL_NAME is not specified!" | tee -a $LOG_FILE > $INFER_DISPLAY
        exit 1
    fi

    echo "MODEL_NAME: $MODEL_NAME" | tee -a $LOG_FILE > $INFER_DISPLAY
    GODLEN_BIN=$(ls infer_out_600/$MODEL_NAME)

    if [ -z "$GODLEN_BIN" ]; then
        echo "No reference output found!" | tee -a $LOG_FILE > $INFER_DISPLAY
        exit 1
    fi

    test_freq=$ARGS_FREQ
    freq_step=$ARGS_DOWN
    freq_ok=0
    while :
    do
        echo "Test Frequency: $test_freq" | tee -a $LOG_FILE > $INFER_DISPLAY
        $CNN_FREQ_TOOL -f $test_freq

        c=0
        failed=0
        while [ $c -lt $ARGS_CYCLE ]; do
            c=$((c+1))
            echo -ne "\rCycle $c/$ARGS_CYCLE" | tee -a $LOG_FILE > $INFER_DISPLAY

            echo "<<${test_freq} MHz, Cycle $c/$ARGS_CYCLE>>" >> $INFER_TOOL_LOG 2>&1
            $INFER_TOOL $INFER_TOOL_ARGS >> $INFER_TOOL_LOG 2>&1
            sync
            for outbin in $GODLEN_BIN; do
                echo "Comparing ${outbin}" >> $INFER_TOOL_LOG 2>&1
                diff_text=$(cmp -l ./infer_out_600/$MODEL_NAME/${outbin} ./infer_out/${MODEL_NAME}/${outbin})
                diff_bytes=$(echo "$diff_text" | wc -w)
                
                if [ $diff_bytes -gt 0 ]; then
                    failed=$((failed + 1))
                    break;
                fi
            done
            if [ $failed -gt 0 ]; then
                break;
            fi
        done

        if [ $failed -eq 0 ]; then
            echo "Test Frequency: $test_freq [Y]" | tee -a $LOG_FILE > $INFER_DISPLAY
            freq_ok=$test_freq
            if [ $ARGS_UP -eq 0 ]; then
                break;
            fi
            freq_step=$ARGS_UP
        else
            echo "Test Frequency: $test_freq [N]" | tee -a $LOG_FILE > $INFER_DISPLAY
            if [ $freq_step -gt 0 ]; then
                break;
            fi
            freq_step=$ARGS_DOWN
        fi

        test_freq=$(($test_freq + $freq_step))

        if [ $test_freq -lt 600 ]; then
            echo "Test Failed! No more test frequency!" | tee -a $LOG_FILE > $INFER_DISPLAY
            break;
        fi
        if [ $test_freq -gt $ARGS_FREQ ]; then
            echo "Test Over Limit!" | tee -a $LOG_FILE > $INFER_DISPLAY
            break;
        fi
    done
    freq_ok=$(((freq_ok/4)*4))
    echo "[Final: $freq_ok MHz, MODEL_NAME: $MODEL_NAME]" | tee -a $LOG_FILE > $INFER_DISPLAY
    exit $freq_ok
    
else
    GOLDEN_FREQ=600
    echo "|-- Golden, Frequency: $GOLDEN_FREQ MHz --|" | tee -a $LOG_FILE > $INFER_DISPLAY

    if [ -d "infer_out_600" ]; then
        rm -rf infer_out_600
    fi
    $CNN_FREQ_TOOL -f $GOLDEN_FREQ
    $INFER_TOOL $INFER_TOOL_ARGS >> $INFER_TOOL_LOG 2>&1
    sync
    mv infer_out infer_out_600
    exit 0
fi

