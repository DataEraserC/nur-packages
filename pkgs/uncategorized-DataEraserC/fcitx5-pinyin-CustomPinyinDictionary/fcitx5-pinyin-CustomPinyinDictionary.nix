{
  lib,
  stdenvNoCC,
  sources,
}:

stdenvNoCC.mkDerivation {

  inherit (sources.AAA_CustomPinyinDictionary_Fcitx) pname version src;

  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/share/fcitx5/pinyin/dictionaries
    cp $src $out/share/fcitx5/pinyin/dictionaries/CustomPinyinDictionary_Fcitx.dict
    chmod 644 $out/share/fcitx5/pinyin/dictionaries/CustomPinyinDictionary_Fcitx.dict
  '';

  meta = with lib; {
    description = "自建拼音输入法词库，百万常用词汇量，适配 Fcitx5 (Linux / Android) 及 Gboard (Android + Magisk or KernelSU)";
    homepage = "https://github.com/wuhgit/CustomPinyinDictionary";
    license = licenses.unlicense;
  };
}
