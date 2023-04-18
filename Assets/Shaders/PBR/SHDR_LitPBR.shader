Shader "Custom/SHDR_LitPBR"
{
    Properties 
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _NormalTex ("Normal Map", 2D) = "bump" {}
        _Metallic ("Metallic", Range(0, 0.999)) = 0.0
        _Smoothness ("Smooothness", Range(0.001, 1)) = 0.5
    }

    SubShader 
    {
        Tags 
        {
            "Queue"="Transparent" 
            "RenderType"="Opaque"
        }
        LOD 100

        Pass 
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata 
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f 
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _NormalTex;
            float _Metallic;
            float _Smoothness;

            v2f vert (appdata v) 
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target 
            {
                // Sample albedo texture
                fixed4 albedo = tex2D(_MainTex, i.uv);
                // Get metallic value
                float metallic = _Metallic;
                // Get smoothness value
                float smoothness = _Smoothness;

                // Compute specular
                // get view direction
                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.vertex));
                // get normal from normal map
                float3 normal = UnpackNormal(tex2D(_NormalTex, i.uv));
                // get light direction
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.vertex.xyz);
                // get half vector
                float3 halfVec = normalize(viewDir + lightDir);
                // compute specular
                float3 specular = pow(saturate(dot(halfVec, normal)), smoothness) * metallic;

                // Combine albedo and specular
                return fixed4(albedo.rgb * (1.0 - metallic) + specular.rgb, albedo.a);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
