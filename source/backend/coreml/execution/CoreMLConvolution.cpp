//
//  CoreMLConvolution.cpp
//  MNN
//
//  Created by MNN on 2021/03/25.
//  Copyright © 2018, Alibaba Group Holding Limited
//

#include <float.h>
#include "core/ConvolutionCommon.hpp"
#include "CoreMLConvolution.hpp"

namespace MNN {


CoreMLConvolution::CoreMLConvolution(MNN::Backend *b, const MNN::Op *op, const std::vector<Tensor *> &inputs, const std::vector<MNN::Tensor *> &outputs) : CoreMLCommonExecution(b, op) {
    isDeconv = op->type() == OpType_Deconvolution || op->type() == OpType_DeconvolutionDepthwise;
    initLayer();
}

void CoreMLConvolution::loadWeightBias(const std::vector<Tensor *> &inputs) {
    if (inputs.size() == 3) {
        weightPtr = inputs[1]->host<float>();
        weightSize = inputs[1]->elementSize();
        biasPtr = inputs[2]->host<float>();
        biasSize = inputs[2]->elementSize();
        return;
    }
    if (!mOp) {
        return;
    }
    auto conv2D = mOp->main_as_Convolution2D();
    if (nullptr != conv2D->quanParameter()) {
        quanCommon = ConvolutionCommon::load(mOp, backend(), true);
        if (nullptr == quanCommon) {
            MNN_ERROR("Memory not Enough, can't extract IDST Convolution: %s \n", mOp->name()->c_str());
        }
        if (quanCommon->weightFloat.get() == nullptr) {
            MNN_PRINT("quanCommon->weightFloat.get() == nullptr \n");
        }
        // Back to float
        weightPtr  = quanCommon->weightFloat.get();
        weightSize = quanCommon->weightFloat.size();
    } else {
        weightSize = conv2D->weight()->size();
        weightPtr  = conv2D->weight()->data();
    }
    biasSize = conv2D->bias()->size();
    biasPtr  = conv2D->bias()->data();
}

void CoreMLConvolution::addPadLayer(const Tensor * input, const Tensor * output, const Convolution2DCommon* common) {
    std::pair<int, int> pads;
    if (isDeconv) {
        pads = ConvolutionCommon::convolutionTransposePad(input, output, common);
    } else {
        pads = ConvolutionCommon::convolutionPad(input, output, common);
    }
    int top = pads.second;
    int left = pads.first;
    int bottom = pads.second;
    int right = pads.first;
    if (top == 0 && left == 0 && bottom == 0 && right == 0) {
        return;
    }
    if (isDeconv && outputWidth == inputWidth * common->strideX() && outputHeight == inputHeight * common->strideY()) {
        isSamePadding = true;
        return;
    }
    if (!isDeconv && outputWidth == UP_DIV(inputWidth, common->strideX()) && outputHeight == UP_DIV(inputHeight, common->strideY())) {
        isSamePadding = true;
        return;
    }
    std::string layerName = "ConvPadding-" + mConvInputName;
    auto paddingLayer = mCoreMLBackend->create<CoreML__Specification__NeuralNetworkLayer>();
    core_ml__specification__neural_network_layer__init(paddingLayer);
    paddingLayer->layer_case = CORE_ML__SPECIFICATION__NEURAL_NETWORK_LAYER__LAYER_PADDING;
    mCoreMLBackend->setLayerName(paddingLayer, layerName.c_str());
    paddingLayer->padding = mCoreMLBackend->create<CoreML__Specification__PaddingLayerParams>();
    core_ml__specification__padding_layer_params__init(paddingLayer->padding);
    paddingLayer->padding->padding_type_case = CORE_ML__SPECIFICATION__PADDING_LAYER_PARAMS__PADDING_TYPE_CONSTANT;
    paddingLayer->padding->constant = mCoreMLBackend->create<CoreML__Specification__PaddingLayerParams__PaddingConstant>();
    core_ml__specification__padding_layer_params__padding_constant__init(paddingLayer->padding->constant);
    paddingLayer->padding->constant->value = 0;
    paddingLayer->padding->paddingamounts = mCoreMLBackend->create<CoreML__Specification__BorderAmounts>();
    core_ml__specification__border_amounts__init(paddingLayer->padding->paddingamounts);
    paddingLayer->padding->paddingamounts->n_borderamounts = 2;
    paddingLayer->padding->paddingamounts->borderamounts = mCoreMLBackend->create<CoreML__Specification__BorderAmounts__EdgeSizes*>(2);
    paddingLayer->padding->paddingamounts->borderamounts[0] = mCoreMLBackend->create<CoreML__Specification__BorderAmounts__EdgeSizes>();
    core_ml__specification__border_amounts__edge_sizes__init(paddingLayer->padding->paddingamounts->borderamounts[0]);
    paddingLayer->padding->paddingamounts->borderamounts[0]->startedgesize = top;
    paddingLayer->padding->paddingamounts->borderamounts[0]->endedgesize = bottom;
    paddingLayer->padding->paddingamounts->borderamounts[1] = mCoreMLBackend->create<CoreML__Specification__BorderAmounts__EdgeSizes>();
    core_ml__specification__border_amounts__edge_sizes__init(paddingLayer->padding->paddingamounts->borderamounts[1]);
    paddingLayer->padding->paddingamounts->borderamounts[1]->startedgesize = left;
    paddingLayer->padding->paddingamounts->borderamounts[1]->endedgesize = right;
    auto inputName = mConvInputName;
    mConvInputName = mConvInputName + "-" + mConvOutputName + "-Padding";
    setLayerInputsAndOutputs(paddingLayer, {inputName}, {mConvInputName});
    mCoreMLBackend->addLayer(paddingLayer);
}

ErrorCode CoreMLConvolution::onResize(const std::vector<Tensor *> &inputs, const std::vector<Tensor *> &outputs) {
    mConvInputName = mCoreMLBackend->getTensorName(inputs[0]);
    mConvOutputName = mCoreMLBackend->getTensorName(outputs[0]);
    inputWidth = inputs[0]->width();
    inputHeight = inputs[0]->height();
    outputWidth = outputs[0]->width();
    outputHeight = outputs[0]->height();
    loadWeightBias(inputs);
    isSamePadding = false;
    auto conv2D      = mOp->main_as_Convolution2D();
    auto common      = conv2D->common();
    auto kernelX     = common->kernelX();
    auto kernelY     = common->kernelY();
    auto outputCount = common->outputCount();
    auto strideX     = common->strideX();
    auto strideY     = common->strideY();
    auto dilateX     = common->dilateX();
    auto dilateY     = common->dilateY();
    auto padMod      = common->padMode();
    auto group       = common->group();
    mLayer_->convolution = mCoreMLBackend->create<CoreML__Specification__ConvolutionLayerParams>();
    core_ml__specification__convolution_layer_params__init(mLayer_->convolution);
    mLayer_->layer_case = CORE_ML__SPECIFICATION__NEURAL_NETWORK_LAYER__LAYER_CONVOLUTION;
    mLayer_->convolution->isdeconvolution = isDeconv;
    mLayer_->convolution->ngroups = group;
    mLayer_->convolution->n_stride = 2;
    mLayer_->convolution->stride = mCoreMLBackend->create<uint64_t>(mLayer_->convolution->n_stride);
    mLayer_->convolution->stride[0] = strideY;
    mLayer_->convolution->stride[1] = strideX;
    mLayer_->convolution->n_dilationfactor = 2;
    mLayer_->convolution->dilationfactor = mCoreMLBackend->create<uint64_t>(mLayer_->convolution->n_dilationfactor);
    mLayer_->convolution->dilationfactor[0] = dilateY;
    mLayer_->convolution->dilationfactor[1] = dilateX;
    if (isDeconv) {
        mLayer_->convolution->n_outputshape = 2;
        mLayer_->convolution->outputshape = mCoreMLBackend->create<uint64_t>(2);
        mLayer_->convolution->outputshape[0] = outputHeight;
        mLayer_->convolution->outputshape[1] = outputWidth;
    }
    switch (padMod) {
        case PadMode_SAME:
            mLayer_->convolution->convolution_padding_type_case = CORE_ML__SPECIFICATION__CONVOLUTION_LAYER_PARAMS__CONVOLUTION_PADDING_TYPE_SAME;
            mLayer_->convolution->same = mCoreMLBackend->create<CoreML__Specification__SamePadding>();
            core_ml__specification__same_padding__init(mLayer_->convolution->same);
            break;
        case PadMode_VALID:
            mLayer_->convolution->convolution_padding_type_case = CORE_ML__SPECIFICATION__CONVOLUTION_LAYER_PARAMS__CONVOLUTION_PADDING_TYPE_VALID;
            mLayer_->convolution->valid = mCoreMLBackend->create<CoreML__Specification__ValidPadding>();
            core_ml__specification__valid_padding__init(mLayer_->convolution->valid);
            break;
        case PadMode_CAFFE:
            addPadLayer(inputs[0], outputs[0], common);
            if (isSamePadding){
                mLayer_->convolution->convolution_padding_type_case = CORE_ML__SPECIFICATION__CONVOLUTION_LAYER_PARAMS__CONVOLUTION_PADDING_TYPE_SAME;
                mLayer_->convolution->same = mCoreMLBackend->create<CoreML__Specification__SamePadding>();
                core_ml__specification__same_padding__init(mLayer_->convolution->same);
                mLayer_->convolution->same->asymmetrymode = CORE_ML__SPECIFICATION__SAME_PADDING__SAME_PADDING_MODE__TOP_LEFT_HEAVY;
                break;
            } else {
                mLayer_->convolution->convolution_padding_type_case = CORE_ML__SPECIFICATION__CONVOLUTION_LAYER_PARAMS__CONVOLUTION_PADDING_TYPE_VALID;
                mLayer_->convolution->valid = mCoreMLBackend->create<CoreML__Specification__ValidPadding>();
                core_ml__specification__valid_padding__init(mLayer_->convolution->valid);
                break;
            }
        default:
            break;
    }
    if (isDeconv) {
        mLayer_->convolution->kernelchannels = inputs[0]->channel();
    } else {
        mLayer_->convolution->kernelchannels = weightSize / (kernelX * kernelY * outputCount);
    }
    mLayer_->convolution->outputchannels = outputCount;
    mLayer_->convolution->n_kernelsize = 2;
    mLayer_->convolution->kernelsize = mCoreMLBackend->create<uint64_t>(mLayer_->convolution->n_kernelsize);
    mLayer_->convolution->kernelsize[0] = kernelY;
    mLayer_->convolution->kernelsize[1] = kernelX;

    mLayer_->convolution->weights = mCoreMLBackend->create<CoreML__Specification__WeightParams>();
    core_ml__specification__weight_params__init(mLayer_->convolution->weights);
    mLayer_->convolution->weights->n_floatvalue = weightSize;
    mLayer_->convolution->weights->floatvalue = mCoreMLBackend->create<float>(weightSize);
    memcpy(mLayer_->convolution->weights->floatvalue, weightPtr, weightSize * sizeof(float));
    if (biasPtr) {
        mLayer_->convolution->hasbias = true;
        mLayer_->convolution->bias = mCoreMLBackend->create<CoreML__Specification__WeightParams>();
        core_ml__specification__weight_params__init(mLayer_->convolution->bias);
        mLayer_->convolution->bias->n_floatvalue = biasSize;
        mLayer_->convolution->bias->floatvalue = mCoreMLBackend->create<float>(biasSize);
        memcpy(mLayer_->convolution->bias->floatvalue, biasPtr, biasSize * sizeof(float));
    }
    if (common->relu() || common->relu6()) {
        mConvOutputName = mConvInputName + "-" + mConvOutputName + "-Relu";
    }
    setLayerInputsAndOutputs(mLayer_, {mConvInputName}, {mConvOutputName});
    mCoreMLBackend->addLayer(mLayer_);
    if (common->relu() || common->relu6()) {
        auto reluLayer = mCoreMLBackend->create<CoreML__Specification__NeuralNetworkLayer>();
        core_ml__specification__neural_network_layer__init(reluLayer);
        mCoreMLBackend->setLayerName(reluLayer, "ConvRelu");
        reluLayer->layer_case = CORE_ML__SPECIFICATION__NEURAL_NETWORK_LAYER__LAYER_CLIP;
        reluLayer->clip = mCoreMLBackend->create<CoreML__Specification__ClipLayerParams>();
        core_ml__specification__clip_layer_params__init(reluLayer->clip);
        if (common->relu()) {
            reluLayer->clip->minval = 0.0f;
            reluLayer->clip->maxval = FLT_MAX;
        } else {
            reluLayer->clip->minval = 0.0f;
            reluLayer->clip->maxval = 6.0f;
        }
        setLayerInputsAndOutputs(reluLayer, {mConvOutputName}, {mCoreMLBackend->getTensorName(outputs[0])});
        mCoreMLBackend->addLayer(reluLayer);
    }
    return NO_ERROR;
}

REGISTER_COREML_OP_CREATOR(CoreMLConvolution, OpType_Convolution)
REGISTER_COREML_OP_CREATOR(CoreMLConvolution, OpType_ConvolutionDepthwise)
REGISTER_COREML_OP_CREATOR(CoreMLConvolution, OpType_Deconvolution)
REGISTER_COREML_OP_CREATOR(CoreMLConvolution, OpType_DeconvolutionDepthwise)
} // namespace MNN
