Shader "Unlit/SHDR_GalaxyFX"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FresnelCol ("Fresnel Color", Color) = (1, 1, 1, 1)
        _PanningX ("Panning X", Range(-10, 10)) = 0
        _PanningY ("Panning Y", Range(-10, 10)) = 0
        _Smoothness("Smoothness", Range(0, 1))=0.5
        _SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5)
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque"
            "LightMode" = "ForwardBase" 
        
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityStandardBRDF.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half3 normal : NORMAL;
                half3 viewDir : TEXCOORD1;
                half4 screenPosition : TEXCOORD2;
                float3 worldPos: TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _FresnelCol;
            float _Smoothness;
            float4 _SpecularTint;
            fixed _PanningX, _PanningY;

            v2f vert (appdata v)
            {
                v2f o;
                o.normal = v.normal;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = normalize(o.worldPos - _WorldSpaceCameraPos);
                
                o.screenPosition = ComputeScreenPos(o.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                i.normal  = normalize(i.normal);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 halfVector = normalize(lightDir + viewDir);
                float3 lightColor = _LightColor0.rgb;
                float3 diffuse = lightColor * DotClamped(lightDir,i.normal);
                float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector,i.normal),_Smoothness * 100);


                float2 screenSpaceUV = i.screenPosition.xy / i.screenPosition.w;
                float ratio = _ScreenParams.x / _ScreenParams.y;
                screenSpaceUV.x *= ratio;
        
                float4 col = tex2D(_MainTex, screenSpaceUV + float2(_PanningX, _PanningY) * _Time.y);

                fixed fresnel = dot(i.viewDir * -1, i.normal);
                fixed4 fresnelCol = lerp(_FresnelCol, col, fresnel);

                return fresnelCol * float4(diffuse + specular,1);
            }
            ENDCG
        }
    }
}
