#!/usr/bin/env bash

# Copyright (c) 2020 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


cur_model_list=(dy_bert dy_lac dy_transformer dy_wavenet dy_senta dy_yolov3 dy_slowfast dy_tsn dy_tsm dy_gan dy_seg dy_seq2seq dy_resnet dy_ptb_medium dy_mobilenet dy_ppocr_mobile_2 dy_bmn dy_faster_rcnn_fpn \
dy_seg_repo dy_speech_repo_pwgan dy_video_TimeSformer dy_xlnet dy_detection_repo dy_ocr_repo dy_clas_repo dy_gan_repo dy_gpt dy_speech_repo_conformer)


#if  [ ${RUN_PROFILER} = "PROFILER" ]; then
#    log_path=${PROFILER_LOG_DIR:-$(pwd)}  #  benchmark系统指定该参数,如果需要跑profile时,log_path指向存profile的目录
#fi
export log_path=${LOG_PATH_INDEX_DIR:-$(pwd)}  #  benchmark系统指定该参数,不需要跑profile时,log_path指向存speed的目录

dy_seg_repo(){
    echo "dy_seg_repo"
    cur_model_path=${BENCHMARK_ROOT}/PaddleSeg/
    cd ${cur_model_path}
    sed -i '/set\ -xe/d' benchmark/run_benchmark.sh
    bash benchmark/run_all.sh
}

dy_gan_repo(){
    echo "dy_gan_repo"
    cur_model_path=${BENCHMARK_ROOT}/PaddleGAN/
    cd ${cur_model_path}
    ln -s ${data_path}/dygraph_data/gan_repo/REDS/ ./data/
    pip install -v -e .
    sed -i '/set\ -xe/d' benchmark/run_benchmark.sh
    bash benchmark/run_all.sh
}

dy_speech_repo_pwgan(){
    echo "dy_speech_repo_pwgan"
    cur_model_path=${BENCHMARK_ROOT}/PaddleSpeech/
    cd ${cur_model_path}/tests/benchmark/pwgan/
    pip install jsonlines
    bash run_all.sh
}

dy_speech_repo_conformer(){
    echo " dy_speech_repo_conformer prepare python3 env "
	cd ${BENCHMARK_ROOT}/
    ln -s $(which python3.7) run_env/python3
    ln -s $(which pip3.7) run_env/pip3
    export PATH=$(pwd)/run_env:${PATH}
    echo "dy_speech_repo_conformer"
    cur_model_path=${BENCHMARK_ROOT}/PaddleSpeech/
    cd ${cur_model_path}/tests/benchmark/conformer/
    rm -rf ${cur_model_path}/dataset/aishell/aishell.py
    cp ${data_path}/dygraph_data/conformer/aishell.py ${cur_model_path}/dataset/aishell/
    pip install loguru
    echo "bash run.sh --stage 0 --stop_stage 0" >> prepare.sh             # 第一轮数据处理会报错
	bash prepare.sh             
    bash run.sh
    rm -rf ${BENCHMARK_ROOT}/PaddleSpeech/dataset/aishell    # 避免数据集占用docker内过多空间,在执行最后一个模型后删掉
}

dy_video_TimeSformer(){
    echo "dy_video_TimeSformer"
    cur_model_path=${BENCHMARK_ROOT}/PaddleVideo/
    cd ${cur_model_path}/benchmark/TimeSformer/
    pip install -r requirements.txt
    pip install scikit-image==0.18.2
    pip install pooch==1.5.2
    bash run_all.sh local
    rm -rf ${BENCHMARK_ROOT}/PaddleVideo/    # 避免数据集占用docker内过多空间,在执行最后一个模型后删掉
}

dy_detection_repo(){
    echo "dy_detection_repo"
    cur_model_path=${BENCHMARK_ROOT}/PaddleDetection/
    pip install numpy -U
    cd ${cur_model_path}/
    sed -i '/set\ -xe/d' benchmark/run_benchmark.sh
    bash benchmark/run_all.sh
}

dy_ocr_repo(){
    echo "dy_ocr_repo"
    cur_model_path=${BENCHMARK_ROOT}/PaddleOCR/
    cd ${cur_model_path}/
    sed -i '/set\ -xe/d' benchmark/run_benchmark_det.sh
    bash benchmark/run_det.sh
}

dy_clas_repo(){
    echo "dy_clas_repo"
    cur_model_path=${BENCHMARK_ROOT}/PaddleClas/
    cd ${cur_model_path}/
    package_check_list=(imageio tqdm Cython pycocotools tb_paddle scipy pandas wget h5py sklearn opencv-python visualdl)
    for package in ${package_check_list[@]}; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            echo "${package} have already installed"
        else
            echo "${package} NOT FOUND"
            pip install ${package}
            echo "${package} installed"
        fi
    done
    # prepare data    # 脚本内为下载ILSVRC2012,太过耗时
    mkdir -p ./dataset/ILSVRC2012
    ln -s ${data_path}/dygraph_data/imagenet100_data/* ./dataset/ILSVRC2012
    sed -i '/set\ -xe/d' benchmark/run_benchmark.sh
    bash benchmark/run_all.sh
}


#run_bert
dy_bert(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP/examples/language_model/bert/
    cd ${cur_model_path}
    ln -s ${data_path}/Bert/hdf5_lower_case_1_seq_len_512_max_pred_80_masked_lm_prob_0.15_random_seed_12345_dupe_factor_5/wikicorpus_en_seqlen512 ${cur_model_path}/wikicorpus_en_seqlen512 ./data
    ln -s ${data_path}/Bert/wikicorpus_en_seqlen128 ./data
    rm -rf run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/bert/paddle/run_benchmark.sh ./run_benchmark.sh
    pip install paddlenlp

    sed -i '/set\ -xe/d' run_benchmark.sh
    model_mode_list=(base large)
    fp_mode_list=(fp32 fp16)
    for model_mode in ${model_mode_list[@]}; do
        bs_list=(96)
        seq_item=(seqlen128)
        if [ ${model_mode} == "large" ]; then
            bs_list=(4)
            seq_item=(seqlen512) # prepare for test large seqlen128|seqlen512
        fi

        for fp_mode in ${fp_mode_list[@]}
        do
            for bs_item  in ${bs_list[@]}
            do
                model_name="bert_${model_mode}_${fp_mode}_${seq_item}_bs${bs_item}"
                echo "index is speed, 1gpus, begin, ${model_name}"
                CUDA_VISIBLE_DEVICES=0 bash run_benchmark.sh 1 ${model_mode} ${fp_mode} sp ${bs_item} 500 ${seq_item} | tee ${log_path}/${model_name}_speed_1gpus 2>&1
                sleep 60
                echo "index is speed, 8gpus, run_mode is multi_process, begin, ${model_name}"
                CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 ${model_mode} ${fp_mode} mp ${bs_item} 400  ${seq_item} | tee ${log_path}/${model_name}_speed_8gpus8p 2>&1
                sleep 60
            done
        done
    done
}

# MobileNet
dy_mobilenet(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleClas
    cd ${cur_model_path}
    pip install -r requirements.txt

    # Prepare data
    ln -s ${data_path}/dygraph_data/imagenet100_data ${cur_model_path}/dataset/         # 准备数据集,需>要保证benchmark任务极其21 上对应目录下存在该数据集！

    # Running ...
    rm -f ./run_benchmark_mobilenet.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/mobilenet/paddle/run_benchmark_mobilenet.sh ./       # 拷贝脚本到当前目录
    sed -i '/set\ -xe/d' run_benchmark_mobilenet.sh
    modle_list=(MobileNetV2 MobileNetV1)
    for model_name in ${modle_list[@]}
    do
        echo "------------> begin to run ${model_name}"
        echo "index is speed, 1gpu begin"
        CUDA_VISIBLE_DEVICES=5 bash run_benchmark_mobilenet.sh 1  sp 1  ${model_name} | tee ${log_path}/dynamic_${model_name}_bs128_speed_1gpus 2>&1
        sleep 60
        echo "index is speed, 8gpus, begin"
        CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark_mobilenet.sh 1  mp  1 ${model_name} | tee ${log_path}/dynamic_${model_name}_bs128_speed_8gpus 2>&1
        sleep 60
    done
}

# seq2seq
dy_seq2seq(){
    cur_model_path=${BENCHMARK_ROOT}/models/dygraph/seq2seq
    cd ${cur_model_path}

    # Prepare data
    ln -s ${data_path}/dygraph_data/seq2seq/data/ ${cur_model_path}/data

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/seq2seq/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh 1 1 | tee ${log_path}/dynamic_seq2seq_bs128_speed_1gpus 2>&1
}

# ptb
dy_ptb_medium(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP/examples/language_model/rnnlm
    cd ${cur_model_path}

    # Prepare data
    mkdir -p data
    ln -s ${data_path}/dygraph_data/ptb/simple-examples/ /root/.paddlenlp/datasets/PTB/

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/ptb/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh 1 1 | tee ${log_path}/dynamic_ptb_medium_bs20_speed_1gpus 2>&1
}

# transformer
dy_transformer(){
    echo "###########pip install paddlenlp"
    pip install paddlenlp
    pip install attrdict
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP/examples/machine_translation/transformer
    cd ${cur_model_path}
    # prepare data
    mkdir -p ~/.paddlenlp/datasets
    ln -s ${data_path}/dygraph_data/transformer/WMT14ende ~/.paddlenlp/datasets/ 
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/transformer/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    mode_list=(big base)
    fp_list=(fp32 amp_fp16)
    for mode_item in ${mode_list[@]}
    do
        for fp_item in ${fp_list[@]}
        do
            model_name="transformer_${mode_item}_${fp_item}"
            echo "index is speed, ${model_name} 1gpu begin"
            CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh 1 sp 600 ${mode_item} ${fp_item} | tee ${log_path}/dynamic_${model_name}_speed_1gpus 2>&1
            sleep 60
            echo "index is speed, ${model_name} 8gpus begin, mp"
            CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 500 ${mode_item} ${fp_item} | tee ${log_path}/dynamic_${model_name}_speed_8gpus 2>&1
        done
    done 
}

# tsn 
dy_tsn(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleVideo
    cd ${cur_model_path}

    pip install -r requirements.txt
    pip install wget av
    pip install scikit-image==0.18.2
    pip install pooch==1.5.2
	# Prepare pretrained modles
    rm -rf ResNet50_pretrain.pdparams
    ln -s ${prepare_path}/tsn/ResNet50_pretrain.pdparams ${cur_model_path}/
    # Prepare data
    rm -rf data
    ln -s ${data_path}/dygraph_data/TSN/data ${cur_model_path}/

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/tsn/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 32 TSN sp 1 | tee ${log_path}/dynamic_tsn_bs32_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 32 TSN mp 1 | tee ${log_path}/dynamic_tsn_bs32_speed_8gpus 2>&1
}

# cyclegan and pix2pix
dy_gan(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleGAN
    cd ${cur_model_path}

    if python -c "import pooch" >/dev/null 2>&1; then
        echo "pooch have already installed, need uninstall"
        pip uninstall -y pooch
    else
        echo "pooch not installed"
    fi

    pip install -r requirements.txt
    pip install scikit-image==0.18.2
    # Prepare data
    mkdir -p data
    ln -s ${data_path}/dygraph_data/cityscapes_gan_mini ${cur_model_path}/data/cityscapes

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/gan_models/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    model_list=(Pix2pix CycleGAN)
    for model_item in ${model_list[@]}
    do
        echo "index is speed, ${model_item} 1gpu begin"
        CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh 1 sp ${model_item} 1 | tee ${log_path}/dynamic_gan_${model_item}_bs1_speed_1gpus 2>&1
        sleep 10
    done
}

#deeplabv3 and HRnet
dy_seg(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleSeg/
    cd ${cur_model_path}
    #git checkout develop    # 静态图监控benchmark分支，已将默认分支切为benchmark。故而静态图训练完毕后，需切下分支

    #apt-get install lsb-core -y
    pip install  visualdl
    # Prepare data
    mkdir -p ${cur_model_path}/data
    ln -s ${data_path}/dygraph_data/cityscapes_hrnet_torch ${cur_model_path}/data/cityscapes

    # Running
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/seg_models/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh

    model_list=(deeplabv3 HRnet)
    fp_mode_list=(fp32 fp16)
    for model_item in ${model_list[@]}
    do
        for fp_mode in ${fp_mode_list[@]}
        do
            if [ ${model_item} = "HRnet" ]; then
                bs_item=8
            elif [ ${model_item} = "deeplabv3" ]; then
                bs_item=4
            fi
            echo "index is speed, ${model_item} 1gpu begin"
            CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh 1 ${bs_item} sp ${model_item} 200 False ${fp_mode} | tee ${log_path}/dynamic_seg_${model_item}_bs${bs_item}_${fp_mode}_speed_1gpus 2>&1
            sleep 10
            echo "index is speed, ${model_item} 8gpu begin"
            CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 ${bs_item} mp ${model_item} 200 False ${fp_mode} | tee ${log_path}/dynamic_seg_${model_item}_bs${bs_item}_${fp_mode}_speed_8gpus 2>&1
            sleep 10
        done
    done
}

dy_slowfast(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleVideo
    cd ${cur_model_path}
    pip install -r requirements.txt
    pip install tqdm
    pip install decord
    pip install pandas av
    pip install scikit-image==0.18.2
    pip install pooch==1.5.2
    echo "------------pip list is"
    pip list
    
	# Prepare data
    rm -rf data
    ln -s ${data_path}/dygraph_data/slowfast/data/ ${cur_model_path}/

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/slowfast/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 1 | tee ${log_path}/dynamic_slowfast_bs8_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 1 | tee ${log_path}/dynamic_slowfast_bs8_speed_8gpus 2>&1
}

dy_mask_rcnn(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleDetection
    cd ${cur_model_path}
    pip install Cython
    pip install -r requirements.txt 

    # Install cocoapi
    if python -c "import pycocotools" >/dev/null 2>&1
    then
        echo "cocoapi have already installed"
    else
        echo "cocoapi NOT FOUND"
        cp -r ${prepare_path}/cocoapi/ ./
        cd cocoapi/PythonAPI/
        pip install Cython
        make install
        python setup.py install --user
        echo "cocoapi installed"
    fi

    package_check_list=(imageio tqdm Cython pycocotools tb_paddle scipy)
    for package in ${package_check_list[@]}; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            echo "${package} have already installed"
        else
            echo "${package} NOT FOUND"
            pip install ${package}
            echo "${package} installed"
        fi
    done

    # Copy pretrained model
    ln -s ${prepare_path}/mask-rcnn/ResNet50_cos_pretrained  ~/.cache/paddle/weights
    cd ${cur_model_path}
    # Prepare data
    rm -rf dataset/coco/
    mkdir -p dataset/coco/
    ln -s ${data_path}/COCO17/annotations ${cur_model_path}/dataset/coco/annotations
    ln -s ${data_path}/COCO17/train2017 ${cur_model_path}/dataset/coco/train2017
    ln -s ${data_path}/COCO17/test2017 ${cur_model_path}/dataset/coco/test2017
    ln -s ${data_path}/COCO17/val2017 ${cur_model_path}/dataset/coco/val2017
    # preprare scripts
    rm -rf run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/mask_rcnn/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 500 | tee ${log_path}/dynamic_mask_rcnn_bs1_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 500 | tee ${log_path}/dynamic_mask_rcnn_bs1_speed_8gpus 2>&1
}

dy_yolov3(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleDetection
    git branch    #develop 分支
    cd ${cur_model_path}
    pip install Cython
    pip install -r requirements.txt 
   
    if python -c "import pycocotools" >/dev/null 2>&1
    then
        echo "cocoapi have already installed"
    else
        echo "cocoapi NOT FOUND"
        cp -r ${prepare_path}/cocoapi/ ./
        cd cocoapi/PythonAPI/
        pip install Cython
        make install
        python setup.py install --user
        echo "cocoapi installed"
    fi

    mkdir -p ~/.cache/paddle/weights
    ln -s ${prepare_path}/yolov3/DarkNet53_pretrained ~/.cache/paddle/weights
    cd ${cur_model_path}
    echo "-------before data prepare"
    ls -l ./dataset/coco/
    ln -s ${data_path}/coco/* ./dataset/coco/
    pip install -r ./dataset/coco/requirements.txt
    echo "-------after data prepare"
    ls -l ./dataset/coco/
    rm -rf run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/yolov3/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu, begin"
    CUDA_VISIBLE_DEVICES=0 bash run_benchmark.sh 1 sp 500 | tee ${log_path}/dynamic_yolov3_bs1_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpu, begin"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 500 | tee ${log_path}/dynamic_yolov3_bs1_speed_8gpus 2>&1
}

# tsm 
dy_tsm(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleVideo
    cd ${cur_model_path}

    pip install -r requirements.txt
    pip install wget av decord
    pip install scikit-image==0.18.2
    pip install pooch==1.5.2
    # Prepare pretrained modles
    ln -s ${prepare_path}/tsm/ResNet50_pretrain.pdparams ${cur_model_path}/
    # Prepare data
    rm -rf ./data/ucf101
    ln -s ${data_path}/dygraph_data/TSM/ucf101_Vedio/ ${cur_model_path}/data/ucf101

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/tsm/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 1 | tee ${log_path}/dynamic_tsm_bs_16_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 1 | tee ${log_path}/dynamic_tsm_bs16_speed_8gpus 2>&1
}

# wavenet
dy_wavenet(){
    rm -rf ${BENCHMARK_ROOT}/SL_models/
    cp -r ${all_path}/SL_models/ ${BENCHMARK_ROOT}  # 当前SL 方向模型在gitlab托管，不对外开源。故而会在任务开始时克隆SL 代码
    # 地址：http://gitlab.baidu.com/heya02/benchmark/
    cur_model_path=${BENCHMARK_ROOT}/SL_models/benchmark/wavenet/paddle_implementation
    cd ${cur_model_path}

    # Prepare data
    ln -s ${data_path}/dygraph_data/wavenet/ljspeech ${cur_model_path}/

    apt-get install  libsndfile1 -y
    pip install -r ${data_path}/dygraph_data/wavenet/requirement.txt 
    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/wavenet/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    kill -9 `ps -ef|grep python |awk '{print $2}'`
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp | tee ${log_path}/dynamic_wavenet_bs8_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    kill -9 `ps -ef|grep python |awk '{print $2}'`
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp | tee ${log_path}/dynamic_wavenet_bs8_speed_8gpus 2>&1
}

dy_senta(){
    rm -rf ${BENCHMARK_ROOT}/SL_models/
    cp -r ${all_path}/SL_models/ ${BENCHMARK_ROOT}  # 当前SL 方向模型在gitlab托管，不对外开源。故而会在任务开始时克隆SL 代码
    # 地址：http://gitlab.baidu.com/heya02/benchmark/
    cur_model_path=${BENCHMARK_ROOT}/SL_models/benchmark/senta/paddle2
    cd ${cur_model_path}

    # Prepare data
    ln -s ${data_path}/dygraph_data/senta/senta_data ${cur_model_path}/

    pip install tqdm

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/senta/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    net_list=(bow lstm bilstm gru bigru rnn birnn cnn)
    for net_item in ${net_list[@]}
    do
        echo "net is ${net_item}, index is speed, 1gpu begin"
        model_name="Senta"_${net_item}_bs64
        CUDA_VISIBLE_DEVICES=0 bash run_benchmark.sh 1 ${net_item} sp 2 | tee ${log_path}/dynamic_${model_name}_speed_1gpus 2>&1
        kill -9 `ps -ef|grep python |awk '{print $2}'`
        sleep 60
        echo "net is ${net_item}, index is speed, 8gpu begin"
        CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 ${net_item} mp 2 | tee ${log_path}/dynamic_${model_name}_speed_8gpus 2>&1
        kill -9 `ps -ef|grep python |awk '{print $2}'`
    done
}

dy_resnet(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleClas
    cd ${cur_model_path}
    pip install -r requirements.txt
   
    ln -s ${data_path}/dygraph_data/imagenet100_data/ ${cur_model_path}/dataset
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/resnet/paddle/run_benchmark_resnet.sh ./
    sed -i '/set\ -xe/d' run_benchmark_resnet.sh
    model_list=(ResNet152_bs32 ResNet50_bs128 ResNet50_amp_fp16_bs128 ResNet50_amp_fp16_bs256 ResNet50_pure_fp16_bs128)
    for model_name in ${model_list[@]}
    do
	batch_size=${model_name#*bs}
        echo "model is ${model_name}, index is speed, 1gpu begin"
        CUDA_VISIBLE_DEVICES=0 bash run_benchmark_resnet.sh 1 ${batch_size} ${model_name} sp 1 | tee ${log_path}/dynamic_${model_name}_speed_1gpus 2>&1
        sleep 60
        echo "model is ${model_name}, index is speed, 8gpu begin"
        CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark_resnet.sh 1 ${batch_size} ${model_name} mp 1 | tee ${log_path}/dynamic_${model_name}_speed_8gpus 2>&1
        sleep 60
    done
}

# lac
dy_lac(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP/examples/lexical_analysis
    cd ${cur_model_path}

    # Prepare data
    ln -s ${data_path}/dygraph_data/lac/lexical_analysis_dataset_tiny/ ${cur_model_path}/data

    echo "###########pip install paddlenlp"
    pip install paddlenlp 
    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/lac/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 10 | tee ${log_path}/dynamic_lac_bs32_speed_1gpus 2>&1
#    八卡报错，暂时监控单卡
#    sleep 60
#    echo "index is speed, 8gpus begin, mp"
#    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh  1 sp 10 | tee ${log_path}/dynamic_lac_bs32_speed_8gpus 2>&1
}

dy_ppocr_mobile_2() {
    cur_model_path=${BENCHMARK_ROOT}/PaddleOCR
    pip install fasttext
    cd ${cur_model_path}

    if python -c "import pooch" >/dev/null 2>&1; then
        echo "pooch have already installed, need uninstall"
        pip uninstall -y pooch
    else
        echo "pooch not installed"
    fi

    package_check_list=(shapely scikit-image imgaug pyclipper lmdb tqdm numpy visualdl python-Levenshtein)
    for package in ${package_check_list[@]}; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            echo "${package} have already installed"
        else
            echo "${package} NOT FOUND"
            pip install ${package}
            echo "${package} installed"
        fi
    done
    # Prepare data
    rm -rf train_data/icdar2015
    if [ ! -d "train_data" ]; then
        mkdir train_data
    fi
    ln -s ${data_path}/dygraph_data/PPOCR_mobile_2.0/icdar2015 ${cur_model_path}/train_data/icdar2015
    rm -rf pretrain_models
    ln -s ${prepare_path}/PPOCR_mobile_2.0/pretrain_models ./pretrain_models

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/ppocr_mobile_2/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 1 | tee ${log_path}/dynamic_ppocr_mobile_2_bs8_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 1 | tee ${log_path}/dynamic_ppocr_mobile_2_bs8_speed_8gpus 2>&1
}

dy_bmn() {
    cur_model_path=${BENCHMARK_ROOT}/PaddleVideo
    cd ${cur_model_path}
    pip install scikit-image==0.18.2
    pip install pooch==1.5.2
    package_check_list=(tqdm PyYAML numpy decord pandas av)
    for package in ${package_check_list[@]}; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            echo "${package} have already installed"
        else
            echo "${package} NOT FOUND"
            pip install ${package}
            echo "${package} installed"
        fi
    done
    # Prepare data
    rm -rf dataset
    ln -s ${data_path}/dygraph_data/bmn ${cur_model_path}/dataset

    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/bmn/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 1 | tee ${log_path}/dynamic_bmn_bs8_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 1 | tee ${log_path}/dynamic_bmn_bs8_speed_8gpus 2>&1
}

dy_faster_rcnn_fpn() {
    cur_model_path=${BENCHMARK_ROOT}/PaddleDetection
    cd ${cur_model_path}
    pip install Cython
    pip install -r requirements.txt

    # Install cocoapi
    if python -c "import pycocotools" >/dev/null 2>&1
    then
        echo "cocoapi have already installed"
    else
        echo "cocoapi NOT FOUND"
        cp -r ${prepare_path}/cocoapi/ ./
        cd cocoapi/PythonAPI/
        pip install Cython
        make install
        python setup.py install --user
        echo "cocoapi installed"
    fi

    package_check_list=(imageio tqdm Cython pycocotools tb_paddle scipy)
    for package in ${package_check_list[@]}; do
        if python -c "import ${package}" >/dev/null 2>&1; then
            echo "${package} have already installed"
        else
            echo "${package} NOT FOUND"
            pip install ${package}
            echo "${package} installed"
        fi
    done

    # Copy pretrained model
    ln -s ${prepare_path}/mask-rcnn/ResNet50_cos_pretrained  ~/.cache/paddle/weights
    cd ${cur_model_path}
    # Prepare data
    rm -rf dataset/coco/
    mkdir -p dataset/coco/
    ln -s ${data_path}/COCO17/annotations ${cur_model_path}/dataset/coco/annotations
    ln -s ${data_path}/COCO17/train2017 ${cur_model_path}/dataset/coco/train2017
    ln -s ${data_path}/COCO17/test2017 ${cur_model_path}/dataset/coco/test2017
    ln -s ${data_path}/COCO17/val2017 ${cur_model_path}/dataset/coco/val2017
    # preprare scripts
    rm -rf run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/faster_rcnn_fpn/paddle/run_benchmark.sh ./
    sed -i '/set\ -xe/d' run_benchmark.sh
    echo "index is speed, 1gpu begin"
    CUDA_VISIBLE_DEVICES=5 bash run_benchmark.sh  1 sp 500 | tee ${log_path}/dynamic_faster_rcnn_bs1_speed_1gpus 2>&1
    sleep 60
    echo "index is speed, 8gpus begin, mp"
    CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh 1 mp 500 | tee ${log_path}/dynamic_faster_rcnn_bs1_speed_8gpus 2>&1
}

dy_gpt(){
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP
    cd ${cur_model_path}
    pip uninstall paddlenlp -y
    echo "python env is"
    ls -l ${BENCHMARK_ROOT}/run_env/
    sed -i "s/python3/python3.7/g"  examples/language_model/data_tools/Makefile  # 模型py3默认使用python37， benchmark 镜像python3 默认py35
    cat examples/language_model/data_tools/Makefile | grep python
    sed -i '/set\ -xe/d' tests/benchmark/run_benchmark.sh
    bash tests/benchmark/run_all.sh dygraph
}


dy_xlnet() {
    cd ${BENCHMARK_ROOT}
    run_env=$BENCHMARK_ROOT/run_env
    cur_model_path=${BENCHMARK_ROOT}/PaddleNLP
    cd ${cur_model_path}

    profile=${1:-"off"}

    # 1. 配置python环境:
    rm -rf $run_env
    mkdir $run_env
    echo `which python3.7`
    ln -s $(which python3.7)m-config  $run_env/python3-config
    ln -s $(which python3.7) $run_env/python
    ln -s $(which pip3.7) $run_env/pip
    export PATH=$run_env:${PATH}

    # 2. 安装该模型需要的依赖 (如需开启优化策略请注明)
    pip install -r requirements.txt -i https://mirror.baidu.com/pypi/simple
    pip install sentencepiece -i https://mirror.baidu.com/pypi/simple # 安装 sentencepiece
    pip install -e ./

    # 3. 拷贝该模型需要数据、预训练模型（这一步无需操作，数据和模型会自动下载）

    # 4. 批量运行（如不方便批量，1，2需放到单个模型中）
    # Running ...
    rm -f ./run_benchmark.sh
    cp ${BENCHMARK_ROOT}/dynamic_graph/xlnet/paddle/run_benchmark.sh ./       # 拷贝脚本到当前目录
    sed -i '/set\ -xe/d' run_benchmark.sh

    model_mode_list=(xlnet-base-cased)
    fp_item_list=(fp32)
    bs_item_list=(32 64 128)
    for model_mode in ${model_mode_list[@]}; do
        for fp_item in ${fp_item_list[@]}; do
            for bs_item in ${bs_item_list[@]}; do
                echo "index is speed, 1gpus, begin, ${model_name}"
                run_mode=sp
                CUDA_VISIBLE_DEVICES=0 bash run_benchmark.sh ${run_mode} ${bs_item} ${fp_item} 300 ${model_mode} ${profile}  | tee ${log_path}/nlp_dygraph_xlnet_sp_bs${bs_item}_fp${fp_item}_speed_1gpus 2>&1    #  (5min)
                #sleep 60
                echo "index is speed, 8gpus, run_mode is multi_process, begin, ${model_name}"
                run_mode=mp
                CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 bash run_benchmark.sh ${run_mode} ${bs_item} ${fp_item} 300 ${model_mode} ${profile}  | tee ${log_path}/nlp_dygraph_xlnet_mp_bs${bs_item}_fp${fp_item}_speed_8gpus 2>&1
                sleep 60
            done
        done
    done
}
