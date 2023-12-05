Automatic Camera Angle Switcher
by Takeyoh

インストール）
7zを解凍し、tky_cameraフォルダを
(assettocorsa install folder)/apps/lua
の下にコピー

アンインストール）
コピーしたtky_cameraフォルダを削除

使い方）
ゲーム起動後メニューから"Automatic Camera Angle Switcher"をクリック。
メニューが表示されたら、「Camera ON/OFF」のチェックボックスをチェックする。（これだけ！）
プリセットした順にカメラアングルを切り替える場合は、「Preset Rotation」をチェックする。
複数台走っている場合、「Car in Focus」でフォーカスする車を選択できます。一番上が自車です。
Preset RotationをONにすると、「Car Rotation」チェックボックスが現れます。
Car Rotationをチェックすると、プリセットが一巡するたびに、フォーカスする車も切り替わっていきます。
「except AI car」をチェックすると、AI車両がフォーカス対象から除外されます。
Car in Focusからも名前が消えます。
マルチプレイなどで一緒に走っているAIは除いてフォーカスを切り替えていきたい場合はチェックを付けてください。
カメラを止めるときは、「CameraON/OFF」のチェックをはずす。

プリセットの使い方）
Preset Settingタブを選択。
各種アングルを上から順番に１０個まで選べます。
preset Rotationのチェックをオンにすると、ここに設定された順番にアングルが自動で切り替わります。
１～１０の選択の左にあるチェックボックスにチェックがついているものだけ再生の対象になります。
気に入った順番が選択出来たら、一番上にあるSAVEボタンを押すと保存されます。
（次回以降ゲーム起動時に保存した順番が読み込まれます。）
SAVE ASボタンは設定ファイルを別名で保存できます。
別名保存したファイルはLOADボタンで読み込みが可能です。

各カメラアングルの調整方法）
Camera ON/OFFにチェック付ける。（カメラを有効化）
preset Rotationのチェックを外す。
Camera Settingタブの「Select Camera Angle」で見たいアングルを選択。

（さらに上級者向け）
「Select Camera Angle」でアングルを選択すると、そのアングルの詳細設定が下に表示されます。
該当するカメラアングルのFOV、Exposure、 DOF、shake powerのスライダーを動かすとリアルタイムに設定が反映されます。
DOFを0に設定すると、車とカメラの距離に合わせてDOFが動的に変化します。
timeはプリセットで選択されたときの再生時間です。
一通りお気に入りの設定が出来たら、advancedタブの一番上にあるSAVEボタンを押すと、
各アングルごとの上記値が保存され次回起動以降も読み込まれます。
SAVE ASボタンは設定ファイルを別名で保存できます。
別名保存したファイルはLOADボタンで読み込みが可能です。

テンキーへのアングル割り当て方法）
「numPad Setting」タブを選択すると、テンキー（NumPadキー）の0～9の一覧が表示されます。
それぞれのキーに割り当てたいアングルを設定します。
SAVE、SAVE AS、LOADの使い方は上記と同じです。
Camera ON/OFFにチェックを付け（カメラを有効化）、テンキー（NumPadキー）を押すと、
割り当てられたアングルに切り替わります。



(更新履歴）
ver 1.1.0
同名の車が複数走っている場合、フォーカスする車が切り替えられなかった事象を修正。
Car Rotationチェックを追加。
チェックをONにすると、presetが一周するたびに、次の車にフォーカスが移動していく。

ver 1.0.6
テンキーでのカメラ切り替え時にアングルの名前を非表示に変更。

ver 1.0.5
CSPのバージョンによって、カメラが車を追従できないバグを修正。

ver 1.0.4
ドローン視点以外のアングルに共通のカメラロール（-45度～45度）を設定可能。

ver 1.0.3
テンキーでのカメラ切り替え時にアングルの名前を表示するように変更。
ENTERキーでpreset rotationオンが可能。
これによりカメラONの状態でctrl+Hでウィンドウが非表示になっていても、
プリセットの再生、カメラの切り替えができる。

ver 1.0.2
露出（exposure)設定を絶対値から倍率に変更。
（カメラをONにすると、画面が暗くなる事象を改善。）

ver 1.0.1
helicopter viewの修正
static position viewでカメラの高さと向きの修正
（峠道でドリフト時にうまくフォーカスできない事象を軽減）
drone viewの左右移動を微調整
drivers face viewで、ドライバの顔をフォーカスするロジックを修正。
freeCamera有効時、cockpitビューはOnBoardFree（F5カメラ）に切り替えるよう修正。

ver 1.0
スクリプト全体を書き直し
CSPのバージョンによってカメラ制御方法を変える
ドローン視点を追加
settingとadvanceのタブを統合。
camera settingではアングルの切り替え（選択）とその詳細設定変更が可能。
自車以外の車を選択可能。
drivers eyes viewを廃止。

ver 0.10
各アングルにシェイク（画面を揺らす）機能を追加。アングルごとに強さを調整可能。
（あまり強くすると画面酔いするので注意）
static position viewで車両通過後に少しズームするよう修正。

ver 0.9.1 
driver eyes viewで頭が映りこむ事象を修正

ver 0.9
Bird Viewを追加。
drivers faceがCSP ver0.1.79以前でも動作するように修正。
設定ファイルをフォルダで分ける。
各アングルの再生時間を設定できるように変更。

ver 0.8.1
road surface viewでカメラが道路を突き破るのを緩和。

ver 0.8
プリセットおよびカメラ設定をjson形式でSAVE/LOAD。（ver0.7からの移行ではアプリ削除後再インストールが必要）
static position viewで、カメラが道路や壁を突き抜けないように調整。（完全ではないです。）
road surface viewで、カメラがぶれてしまう事象を修正。かつカメラ位置を地面に近づけ、より迫力のあるアングルに修正。
selectタブのスライドバーでカメラアングルを変更するとプリセット再生を停止し、即時にアングルを変更。
テンキーでのカメラスイッチ機能を試験的に実装（無理やり実装。もっといい方法があるはず）


------------------------------
Automatic Camera Angle Switcher
by Takeyoh

(Installation)
Unzip the 7z, and then add the tky_camera folder to
(assettocorsa install folder)/apps/lua
and copy it under

(Uninstallation)
Delete the copied tky_camera folder

(How to use)
After starting the game, click "Automatic Camera Angle Switcher" from the menu.
When the menu appears, check the "Camera ON/OFF" checkbox. (That's it!)
To switch camera angles in the preset order, check the "preset Rotation" checkbox.
If there are multiple cars running, you can select the car to focus on with "Car in Focus". The topmost car is your car.
When Preset Rotation is turned on, a "Car Rotation" checkbox will appear.
When "Car Rotation" is checked, the car in focus will change each time the preset rotates.
If "except AI car" is checked, AI cars will be excluded from the focus.
Check this box if you want to switch the focus to exclude AI cars that are running together in a multiplayer game.
To stop the camera, uncheck "CameraON/OFF.

(How to use presets)
Select the Preset Setting tab.
You can select up to 10 various angles in order from the top.
When the preset Rotation checkbox is checked, the angles will automatically switch in the order set here.
Only those with the checkboxes to the left of the 1-10 selections will be played back.
Once you have selected the order you like, press the SAVE button at the top of the screen to save the file.
(The saved order will be loaded the next time you start the game.)
The SAVE AS button allows you to save the settings file under an alias.
The saved file can be loaded by pressing the LOAD button.

(How to adjust each camera angle)
Check Camera ON/OFF. (Enable the camera)
Uncheck the PRESET ROTATION checkbox.
In the Camera Setting tab, select the angle you want to see in "Select Camera Angle".

(For more advanced users)
When an angle is selected in "Select Camera Angle," the detailed settings for that angle will be displayed below.
Move the FOV, Exposure, DOF, and shake power sliders for the appropriate camera angle to reflect the settings in real time.
If DOF is set to 0, DOF will change dynamically according to the distance between the car and the camera.
time is the playback time when the preset is selected.
Once you have made your favorite settings, press the SAVE button at the top of the ADVANCED tab,
The above values for each angle are saved and will be loaded the next time the program is launched.
The SAVE AS button allows you to save the settings file under an alias.
The saved file can be loaded by pressing the LOAD button.

(How to assign angles to the numeric keypad)
Selecting the "numPad Setting" tab displays a list of numeric keys (NumPad keys) from 0 to 9.
Set the angle you wish to assign to each key.
The usage of SAVE, SAVE AS, and LOAD is the same as above.
Check the Camera ON/OFF checkbox (to activate the camera) and press the numeric keypad (NumPad key),
the camera will switch to the assigned angle.
