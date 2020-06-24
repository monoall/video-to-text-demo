import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pb.dart' as gs;
import 'package:google_speech/recognition_config.dart';
import 'package:google_speech/speech_client_authenticator.dart';
import 'package:google_speech/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text from video DEMO'),
      ),
      body: HomeScreenBody(),
    );
  }
}

class HomeScreenBody extends StatefulWidget {
  @override
  _HomeScreenBodyState createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<HomeScreenBody> {
  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
  bool _isLoading = false;
  File videoFile;
  String text = '';
  VideoPlayerController _controller;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          constraints: BoxConstraints.tight(Size.fromWidth(double.infinity)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                constraints: BoxConstraints.loose(Size.fromHeight(height / 2)),
                padding: EdgeInsets.all(0),
                child: _controller != null && _controller.value.initialized

                    //Video player
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          child: VideoPlayer(_controller),
                        ),
                      )

                    //Placeholder in case no video picked
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: GestureDetector(
                          onTap: () => _process(),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 5,
                                color: Colors.grey[500],
                              ),
                            ),
                            child: Text('+ PICK VIDEO',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 36)),
                          ),
                        ),
                      ),
              ),

              //Recognized text
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Text(text ?? '', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),

              //Button 'Clear'
              if (_controller != null && _controller.value.initialized)
                Container(
                  width: double.infinity,
                  child: RaisedButton(
                    color: Colors.red,
                    onPressed: () {
                      setState(() {
                        _controller = null;
                        videoFile = null;
                        text = null;
                      });
                    },
                    child: Text('CLEAR', style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            alignment: Alignment.center,
            color: Colors.white70,
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  //This function handles all process of decoding and recognizing a video
  void _process() async {
    //Pick file
    String videoPath = await _pickFile();

    //Picked file instance
    videoFile = File(videoPath);

    //If video file is picked, shows it in video player widget
    if (videoFile != null) {
      _controller = VideoPlayerController.file(videoFile)
        ..initialize().then((value) => setState(() {}));
    }

    //Set 'isLoading' status to true so user could see loading indicator
    setState(() => _isLoading = true);

    //Extract and decode audio track from video file
    String audioPath = await _extractAudio(videoPath);

    //Exchange audio for a text
    text = await audioToTextStream(audioPath);

    //Switch off the loading status
    setState(() => _isLoading = false);
  }

  //Extract and decode audio track from video file
  Future<String> _extractAudio(String path) async {
    print('_extractAudio() | path ' + path);

    Directory appDocumentDirectory = await getApplicationDocumentsDirectory();

    //Prepare empty file for audio output
    String audioPath = "${appDocumentDirectory.path}/output-audio.wav";
    print('_extractAudio() | audioPath ' + audioPath);

    //Command for Ffmpeg library
    String command = "-i $path -ss 00:00:00 -to 00:00:59 -ac 1 -ar 16000 $audioPath";
    print('_extractAudio() | command ' + command);

    //Execute command
    await _flutterFFmpeg.execute(command);

    print('=============AUDIO FILE INFO====================');
    await getMediaInfo(audioPath);
    print('================================================');

    return audioPath;
  }

  Future<String> audioToTextStream(String path) async {
    File file = File(path);



    String serviceAccountJson =
        await rootBundle.loadString('assets/acc-6193d028bc5e.json');
    final serviceAccount = ServiceAccount.fromString(serviceAccountJson);
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);

    final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.video,
        sampleRateHertz: 16000,
        enableAutomaticPunctuation: true,
        languageCode: 'en-US');

    final audio = file.readAsBytesSync().toList();

    gs.RecognizeResponse response = await speechToText.recognize(config, audio);

    String result = '';

    response.results.forEach((element) {
      result += element.alternatives.first.transcript + '\n';
      print(element.alternatives.first.transcript);
    });

    print('RECOGNIZED RESPONSE ENDED');

    file.delete();

    return result;
  }



  //Pick file
  Future<String> _pickFile() async {
    File file = await FilePicker.getFile(type: FileType.video);
    print('pickFile() path: ' + file.path);
    return file.path;
  }

  //print media info
  Future<void> getMediaInfo(String path) async {
    final FlutterFFprobe _flutterFFprobe = new FlutterFFprobe();

    var info = await _flutterFFprobe.getMediaInformation(path);
    print(info);
  }
}
