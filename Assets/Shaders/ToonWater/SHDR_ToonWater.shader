Shader "Unlit/SHDR_ToonWater"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ColorA ("Water Color", Color) = (0, 0, 0, 1)
        _ColorB ("Foam Color", Color) = (1, 1, 1, 1)
        _Speed ("Speed", Range(-10, 10)) = 1
        _Amplitude ("Amplitude", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
                half3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half3 normal : NORMAL;
                float3 worldPos: TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _ColorA, _ColorB;
            float _Speed;
            float _Amplitude;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);

                float offset = _Amplitude * sin(_Speed * _Time.y + o.worldPos.x);
                o.worldPos += offset * o.normal;
                o.normal = normalize(o.normal);

                o.vertex.xyz += o.normal * o.worldPos * _Amplitude;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);                
                col = lerp(_ColorA, _ColorB, col.x);
                return col;
            }
            ENDCG
        }
    }
}
