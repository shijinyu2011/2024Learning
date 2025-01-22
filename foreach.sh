list_dirs=$(ls .)
export SCRIPT_FOREACH_DIR=$(cd $(dirname $0); pwd)
test_script=./infer_test.sh

final_freq=1200
for d in $list_dirs; do
    if [ ! -d $d ]; then
        continue
    fi
    echo $d
    export MODEL_NAME=$d
    cp $test_script $d/infer/
    cd $d/infer/
    $test_script -g $@
    $test_script $@
    get_freq=$?
    
    if [ $get_freq -lt $final_freq ]; then
        final_freq=$get_freq
    fi
    cd -
done
echo "Minimum frequency: $final_freq MHz"
exit $final_freq
