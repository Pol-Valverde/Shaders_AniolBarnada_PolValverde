Shader "Unlit/SHDR_PBR"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _NormalTex ("Normal", 2D) = "bump" {}
        _NormalVal ("Normal Mult", Range(0, 10)) = 1
        
        _SmoothnessTex ("Smoothness", 2D) = "black" {}
        _SmoothnessVal ("Smoothness Mult", Range(0, 1)) = 1
        
        _MetallicTex ("_Metallic", 2D) = "black" {}
        _MetallicVal ("Metallic Mult", Range(0, 1)) = 1

        _Anisotropy ("Anisotropy", Range(0, 1)) = 0
        _AmbientCol ("AmbientCol", Color) = (0.5, 0.5, 0.5, 1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "LightMode"="ForwardBase"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define PI 3.14159265359

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                half3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                half3 normalWS : NORMAL;
                float4 tangentWS : TANGENT;
                half3 bitangentWS : TEXCOORD1;
                half3 wpos : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex, _NormalTex, _SmoothnessTex, _MetallicTex;
            fixed _NormalVal, _SmoothnessVal, _MetallicVal, _Anisotropy;
            fixed4 _AmbientCol;
            float4 _MainTex_ST;

            float trowbridgeReitzNDF(float NdotH, float roughness)
            {
                float alpha = roughness * roughness;
                float alpha2 = alpha * alpha;
                float NdotH2 = NdotH * NdotH;
                float denominator = PI * pow((alpha2 - 1) * NdotH2 + 1, 2);
                return alpha2 / denominator;
            }
 
            float trowbridgeReitzAnisotropicNDF(float NdotH, float roughness, float anisotropy, float HdotT, float HdotB)
            {
                float aspect = sqrt(1.0 - 0.9 * anisotropy);
                float alpha = roughness * roughness;
 
                float roughT = alpha / aspect;
                float roughB = alpha * aspect;
 
                float alpha2 = alpha * alpha;
                float NdotH2 = NdotH * NdotH;
                float HdotT2 = HdotT * HdotT;
                float HdotB2 = HdotB * HdotB;
 
                float denominator = PI * roughT * roughB * pow(HdotT2 / (roughT * roughT) + HdotB2 / (roughB * roughB) + NdotH2, 2);
                return 1 / denominator;
            }
 
            // Geometric attenuation functions
            float cookTorranceGAF(float NdotH, float NdotV, float HdotV, float NdotL)
            {
                float firstTerm = 2 * NdotH * NdotV / HdotV;
                float secondTerm = 2 * NdotH * NdotL / HdotV;
                return min(1, min(firstTerm, secondTerm));
            }
 
            float schlickBeckmannGAF(float dotProduct, float roughness)
            {
                float alpha = roughness * roughness;
                float k = alpha * 0.797884560803;  // sqrt(2 / PI)
                return dotProduct / (dotProduct * (1 - k) + k);
            }

            float3 fresnel(float3 F0, float NdotV, float roughness)
            {
                return F0 + (max(1.0 - roughness, F0) - F0) * pow(1-NdotV,5);
            }
 
            float3x3 CreateTangentToWorld(float3 normal, float3 tangent, float flipSign)
            {
                // For odd-negative scale transforms we need to flip the sign
                float sgn = flipSign;
                float3 bitangent = cross(normal, tangent) * sgn;
 
                return float3x3(tangent, bitangent, normal);
            }

            float3 TransformTangentToWorld(float3 normalTS, float3x3 tangentToWorld)
            {
                // Note matrix is in row major convention with left multiplication as it is build on the fly
                float3 result = mul(normalTS, tangentToWorld);
 
                return normalize(result);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wpos = mul((float3x3)unity_ObjectToWorld, v.vertex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = float4(UnityObjectToWorldNormal(v.tangent.xyz), v.tangent.w);
                o.bitangentWS = normalize(cross(o.tangentWS.xyz, o.normalWS));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 albedo = tex2D(_MainTex, i.uv);

                // normal and tangent calc
                half3 normalWS = normalize(i.normalWS);
                half3 normalTS = UnpackNormal(tex2D(_NormalTex, i.uv));
                float3x3 tangentToWorld = CreateTangentToWorld(normalWS, i.tangentWS.xyz, i.tangentWS.w);
                normalWS = TransformTangentToWorld(normalTS, tangentToWorld);

                // calculate additional vectors
                float3 viewDir = normalize(i.wpos - _WorldSpaceCameraPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0);
                float3 halfDir = normalize(viewDir + lightDir);
                
                // dots
                float NdotL = max(0.0, dot(normalWS, lightDir));
                float NdotH = max(0.0, dot(halfDir, normalWS));
                float NdotV = max(0.0, dot(normalWS, viewDir));
                float HdotT = dot(halfDir, i.tangentWS.xyz);
                float HdotB = dot(halfDir, i.bitangentWS);

                // sampler PBR textures
                float smoothness = saturate(min(1 - _SmoothnessVal, 1 - tex2D(_SmoothnessTex, i.uv)).r);
                float metallic = saturate(max(_MetallicVal, tex2D(_MetallicTex, i.uv)).r);

                // distributions
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
 
                float D = trowbridgeReitzNDF(NdotH, smoothness);
                D = trowbridgeReitzAnisotropicNDF(NdotH, smoothness, _Anisotropy, HdotT, HdotB);
                float3 F = fresnel(F0, NdotV, smoothness);
                float G = schlickBeckmannGAF(NdotV, smoothness) * schlickBeckmannGAF(NdotL, smoothness);

                fixed4 col = float4(0, 0, 0, 1);
                fixed3 lightValue = max(0.0, dot(normalWS, lightDir)) * _LightColor0.rgb;
                lightValue += _AmbientCol;

                float3 diffuse = albedo * (1 - F) * (1 - metallic);
                float3 specular = G * D * F / (4 * NdotV * NdotL);

                col.rgb = float4(saturate((diffuse + saturate(specular)) * lightValue), 1);

                return col;
            }
            ENDCG
        }
    }
}
