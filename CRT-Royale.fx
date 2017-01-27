/*
    CRT-Royale, ported by luluco250 from RetroArch
*/

//Preprocessor///////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "ReShade.fxh"

//Statics////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static const float fPI = 3.141592653589;
static const float fUnderHalf = 0.4995;

//Uniforms///////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform bool bGammaEncodeOutput <
    ui_label = "Gamma Encode Output";
> = true;

uniform float fGamma <
    ui_label = "Gamma";
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 3.0;
    ui_step = 0.001;
> = 2.2;

uniform bool bInterlaceDetect <
    ui_label = "Interlace Detect";
    ui_tooltip = "Detect interlacing?";
> = true;

uniform bool bInterlaceBFF <
    ui_label = "Interlace BFF";
    ui_tooltip = "For interlaced sources, assume TFF (top-field first) or BFF order?\nWhether this matters depends on the nature of the interlaced input.";
> = false;

uniform bool bInterlace1080i <
    ui_label = "Interlace 1080i";
    ui_tooltip = "Assume 1080-line sources are interlaced?";
> = false;

uniform int framecount <source = "framecount";>;

//Textures///////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Samplers///////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Functions//////////////////////////////////////////////////////////////////////////////////////////////////////////////

float fmod(float a, float b) {
    float c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

float2 fmod(float2 a, float2 b) {
    float2 c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

float3 fmod(float3 a, float3 b) {
    float3 c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

float4 fmod(float4 a, float4 b) {
    float4 c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

float4 tex2Dlinearize(sampler sp, float2 uv) {
    float4 col = tex2D(sp, uv);
    col.rgb = pow(col.rgb, 2.2);
    return col;
}

float3 ToLinear(float3 col) {
    return pow(col, 2.2);
}

float3 ToGamma(float3 col) {
    return pow(col, 1.0 / 2.2);
}

/*float GetGamma() {
    return 2.2;
}

float3 EncodeOutput(float3 color) {
    if (gammaEncodeOutput) {
        //alpha is always opaque, we're not going to use assumeOpaqueAlpha
        return float3(pow(col, 1.0 / getOutputGamma()));
    }
    else {
        return color;
    }
    return pow(col, 1.0 / GetGamma());
}*/

bool isInterlaced(float numLines) {
    if (bInterlaceDetect) {
        bool sdInterlace = ((numLines > 288.5) && (numLines < 576.5));
        bool hdInterlace = bInterlace1080i ? ((numLines > 1079.5) && (numLines < 1080.5)) : false;
        return (sdInterlace || hdInterlace);
    }
    else return false;
}

float3 tex2DresizeGaussian4x4(sampler sp, float2 uv, float sigma) {
    return 0;
}

//Shaders////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_FirstPass(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    //uvStep seems to be the reciprocal texture size
    float2 v_step = float2(0.0, BUFFER_RCP_HEIGHT);

    float fInterlaced = isInterlaced(BUFFER_HEIGHT);

    float3 currLine = tex2Dlinearize(ReShade::BackBuffer, uv).rgb;
    float3 lastLine = tex2Dlinearize(ReShade::BackBuffer, uv - v_step).rgb;
    float3 nextLine = tex2Dlinearize(ReShade::BackBuffer, uv + v_step).rgb;

    float3 interpolatedLine = 0.5 * (lastLine + nextLine);
    //If we're interlacing, determine which field currLine is in
    float modulus = fInterlaced + 1.0;
    float fieldOffset = fmod(framecount + float(bInterlaceBFF), modulus);
    float currLineTexel = uv.y * BUFFER_HEIGHT;
    //Use underHalf to fix a rounding bug around exact texel locations
    float lineNumLast = floor(currLineTexel - fUnderHalf);
    float wrongField = fmod(lineNumLast + fieldOffset, modulus);
    //Select the correct color and output the result
    float3 col = lerp(currLine, interpolatedLine, wrongField);
    
    col = ToGamma(col);

    return float4(col, 1.0);
}

/*float4 PS_BloomApprox(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    float3 col = tex2D(ReShade::BackBuffer, uv).rgb;

    col = pow(col, 2.2);

    if (bGammaEncodeOutput) {
        col = EncodeOutput(col);
    }

    return float4(col, 1.0);
}

float4 PS_Scanlines(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    float3 col = tex2D(ReShade::BackBuffer, uv).rgb;

    return float4(col, 1.0);
}*/

//Technique//////////////////////////////////////////////////////////////////////////////////////////////////////////////

technique CRT_Royale {
    pass FirstPass {
        VertexShader = PostProcessVS;
        PixelShader = PS_FirstPass;
    }
}
