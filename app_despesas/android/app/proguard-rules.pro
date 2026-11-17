# O plugin do ML Kit referencia os modelos de chinês, japonês, coreano e devanágari,
# mas o app só inclui o de alfabeto latino (português). Sem isso o R8 falha no build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
