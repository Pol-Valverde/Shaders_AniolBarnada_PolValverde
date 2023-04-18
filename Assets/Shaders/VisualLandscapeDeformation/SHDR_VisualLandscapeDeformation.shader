Shader "Unlit/SHDR_VisualLandscapeDeformation"
{
    Properties
    {
        _WallTex ("TextureWalls", 2D) = "white" {}
        _FloorTex ("TextureFloor", 2D) = "white" {}
        _HeightMap("HeightMap",2D) = "black"{}
        _Height("Height",Range(0.005,1)) = 0.02
        _FallOff("FallOff",Range(0,2)) = 0.25
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
                float3 worldPosition : TEXCOORD1;
            };

            sampler2D _WallTex;
            sampler2D _FloorTex;
            float4 _WallTex_ST;
            sampler2D _HeightMap;
            half _Height;
            fixed _FallOff;

            v2f vert (appdata v)
            {    
                v2f o;
                float4 heightMap = tex2Dlod(_HeightMap, float4(v.uv.xy, 0, 0));
                o.vertex = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);

                o.vertex.xyz += o.normal * heightMap.b * _Height;

                o.vertex = UnityWorldToClipPos(o.vertex);

                o.uv = TRANSFORM_TEX(v.uv, _WallTex);

                o.worldPosition = mul((float3x3)unity_ObjectToWorld, v.vertex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Calculate uv top (xz)
                float2 uv_top = abs(i.worldPosition.xz);
                // Calculate uv right (yz)
                float2 uv_right = abs(i.worldPosition.yz);
                // Calculate uv forward (xy)
                float2 uv_forward = abs(i.worldPosition.xy);

                // tex2D (_MainTex, uv_top)
                fixed4 col_top = tex2D(_FloorTex, uv_top);
                fixed4 col_right = tex2D(_WallTex, uv_right);
                fixed4 col_forward = tex2D(_WallTex, uv_forward);

                half3 weights;
                // Sampled col top * abs(normal.y)
                weights.y = pow(abs(i.normal.y), _FallOff);
                weights.x = pow(abs(i.normal.x), _FallOff);
                weights.z = pow(abs(i.normal.z), _FallOff);

                weights = weights / (weights.x + weights.y + weights.z);

                col_top *= weights.y;
                col_right *= weights.x;
                col_forward *= weights.z;

                fixed4 col = col_top + col_forward + col_right;
                return col;
            }
            ENDCG
        }
    }
}
