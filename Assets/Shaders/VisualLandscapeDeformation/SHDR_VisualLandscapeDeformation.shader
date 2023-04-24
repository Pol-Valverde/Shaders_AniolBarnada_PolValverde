Shader "Unlit/SHDR_VisualLandscapeDeformation"
{
    Properties
    {
        _WallTex ("TextureWalls", 2D) = "white" {}
        _FloorTex ("TextureFloor", 2D) = "white" {}
        _HeightMap ("HeightMap",2D) = "black"{}
        _Height ("Height",Range(0.005, 10)) = 2
        _FallOff ("FallOff",Range(0, 2)) = 0.25
        _DDist ("Derivative List", Range(0.01, 5)) = 1.0
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
            float4 _HeightMap_ST, _HeightMap_TexelSize;
            half _Height;
            fixed _FallOff;
            fixed _DDist;

            float3 NormalsFromHeight(float4 uv, float texelSize) 
            {     
                float4 h;     
                h[0] = tex2Dlod(_HeightMap, uv + float4(texelSize * float2(0, -1 / _DDist), 0, 0)).r * _Height;
                h[1] = tex2Dlod(_HeightMap, uv + float4(texelSize * float2(-1 / _DDist, 0), 0, 0)).r * _Height;
                h[2] = tex2Dlod(_HeightMap, uv + float4(texelSize * float2(1 / _DDist, 0), 0, 0)).r * _Height;
                h[3] = tex2Dlod(_HeightMap, uv + float4(texelSize * float2(0, 1 / _DDist), 0, 0)).r * _Height;
                
                float3 n;     
                n.z = h[3] - h[0];     
                n.x = h[2] - h[1];     
                n.y = 2;
                
                return normalize(n); 
            } 

            v2f vert (appdata v)
            {    
                v2f o;

                float heightSample = tex2Dlod(_HeightMap, float4(v.uv, 0, 0)).x * _Height;
                o.worldPosition = mul((float3x3)unity_ObjectToWorld, v.vertex).xyz + float4(0, heightSample, 0, 0);
                o.vertex = UnityObjectToClipPos(v.vertex + float3(0, heightSample, 0));
                
                o.normal = NormalsFromHeight(float4(v.uv, 0, 0), _HeightMap_TexelSize.x);
                o.normal = UnityObjectToWorldNormal(o.normal);

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
