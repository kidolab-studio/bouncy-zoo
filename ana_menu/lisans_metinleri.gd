extends RefCounted
# Lisanslar ekranının (lisanslar.gd) sabit metinleri. Godot'un kendi lisansı ve içindeki bileşenler çalışırken
# Engine.get_license_text() / get_copyright_info() / get_license_info() ile okunur; burada yalnızca motorun
# bilmediği şeyler var: yazı tipi lisansı ve indirilen seslerin kaynakları.
# OFL metni ortak/fontlar/OFL.txt ile aynıdır (dışa aktarımda .txt dosyaları pakete girmeyebildiği için buraya
# gömüldü); ses listesi ortak/sesler/SESLER.md ve CREDITS.md ile aynı tutulmalı.

const GIRIS := "Bouncy Zoo'daki bütün çizimler ve seslerin çoğu bu uygulama için özgün olarak hazırlandı. Uygulamada kullanılan açık lisanslı bileşenler aşağıdadır."

const NUNITO_TELIF := "Copyright 2014 The Nunito Project Authors (https://github.com/googlefonts/nunito)"

const SES_ACIKLAMA := "Müzikler ve bazı ses efektleri aşağıdaki CC0 (kamu malı) kaynaklardan alındı ve bu uygulama için düzenlendi. CC0 isim vermeyi gerektirmez; emeği geçenlere teşekkür ederiz. Diğer sesler bu uygulama için üretildi."

const GIZLILIK := """Gizlilik / Privacy

Bu uygulama çevrimdışı çalışır. Kişisel veri, cihaz kimliği, konum, kamera veya mikrofon verisi toplamaz. Reklam, kullanım istatistiği, çökme raporlama, hesap, sosyal özellik ve uygulama içi satın alma yoktur. İnternete bağlanılmaz.

Oyun ilerlemesi, ses tercihi ve Boyama Kitabı eserleri yalnızca bu cihazda saklanır; yayıncıya gönderilmez. Uygulama silinirse yerel kayıtlar kaybolabilir.

This app works offline. It does not collect personal data, device identifiers, location, camera or microphone data. It has no ads, usage measurement, crash reporting, accounts, social features or in-app purchases. It does not connect to the internet.

Game progress, sound preferences and Coloring Book artwork are stored only on this device and are not sent to the publisher. Local records may be lost when the app is deleted.

Güncel gizlilik politikası / Current privacy policy:
https://kidolab-studio.github.io/legal/bouncy-zoo/privacy-policy

Gizlilik soruları için / Privacy questions:
emirsalihgumruk@gmail.com

Bu ekran kısa bir özettir. Ayrıntılı ve güncel politika yukarıdaki adreste bulunur.
This screen is a summary. The full and current policy is available at the address above."""

# [ad, yapan, kaynak]
const SES_KAYNAKLARI := [
	["Interface Sounds, Impact Sounds, Music Jingles, Digital Audio, Casino Audio, RPG Audio", "Kenney", "kenney.nl"],
	["Boing", "Aeva", "opengameart.org/content/boing"],
	["Pleasing Bell Sound Effect", "Spring Spring", "opengameart.org/content/pleasing-bell-sound-effect"],
	["Steam whistle, Steam release sounds", "bart", "opengameart.org/content/steam-whistle"],
	["80 CC0 creature SFX, 30 CC0 SFX loops", "rubberduck", "opengameart.org"],
	["Children's Game Music 3 - Home", "heartade", "opengameart.org/content/childrens-game-music-3-home"],
	["Flowerbed Fields", "Zane Little Music", "opengameart.org/content/flowerbed-fields-loop"],
	["Feel Good Island", "Brandon Morris (döngü: AntumDeluge)", "opengameart.org/content/feel-good-island-loop"],
	["Cozy Puzzle Jingle / Result", "MintoDog", "opengameart.org/content/cozy-puzzle-jingle-result"],
	["Heavenly Loop", "isaiah658", "opengameart.org/content/heavenly-loop"],
	["Children's March Theme", "Cleyton Kauffman", "opengameart.org/content/childrens-march-theme"],
	["Cat Purr & Meow", "Kerzoven", "opengameart.org/content/cat-purr-meow"],
	["Dog Barking Mono", "Brandon Morris", "opengameart.org/content/dog-barking-mono"],
	["Cow Moos #1, Sheep #1, Ducks, Rooster Song", "Joseph Sardin", "bigsoundbank.com"],
	["Ribbit Frog Sounds", "EZduzziteh", "opengameart.org/content/ribbit-frog-sounds"],
]

const OFL := """This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
http://scripts.sil.org/OFL


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded, 
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE."""
