import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '视频元数据编辑器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoMetadataEditor(),
    );
  }
}

class VideoMetadataEditor extends StatefulWidget {
  const VideoMetadataEditor({super.key});

  @override
  _VideoMetadataEditorState createState() => _VideoMetadataEditorState();
}

class _VideoMetadataEditorState extends State<VideoMetadataEditor> {
  String _selectedVideo = '';
  String _title = '';
  String _description = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future _requestPermissions() async {
    final status = await Permission.storage.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('需要存储权限才能使用此应用')),
      );
    }
  }

  Future _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        _selectedVideo = result.files.single.path!;
      });
    }
  }

  Future _addMetadata() async {
    if (_selectedVideo.isEmpty || _title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请选择视频并填写标题')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      String output = _selectedVideo.replaceAll('.mp4', '_edited.mp4');
      String cmd = '-i "$_selectedVideo" -metadata title="$_title" -metadata description="$_description" "$output"';

      await FFmpegKit.execute(cmd);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('元数据添加成功！')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future _savePreset() async {
    if (_title.isEmpty && _description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有可保存的元数据')),
      );
      return;
    }

    String preset = '{"title": "$_title", "description": "$_description"}';
    String? path = await FilePicker.platform.saveFile(
      dialogTitle: '保存预设',
      fileName: 'my_preset.json',
    );

    if (path != null) {
      await File(path).writeAsString(preset);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('预设保存成功！')),
      );
    }
  }

  Future _loadPreset() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null) {
      String preset = await File(result.files.single.path!).readAsString();
      Map<String, dynamic> data = json.decode(preset);
      setState(() {
        _title = data['title'] ?? '';
        _description = data['description'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('预设加载成功！')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('视频元数据编辑器'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _isProcessing
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. 选择视频',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _pickVideo,
                    child: Text('选择视频'),
                  ),
                  Text(_selectedVideo.isNotEmpty ? '已选: $_selectedVideo' : '未选择视频'),
                  SizedBox(height: 20),
                  Text(
                    '2. 填写元数据',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: '标题 *'),
                    onChanged: (value) => _title = value,
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: '描述'),
                    onChanged: (value) => _description = value,
                  ),
                  SizedBox(height: 20),
                  Text(
                    '3. 操作',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _addMetadata,
                        child: Text('添加元数据'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _savePreset,
                        child: Text('保存预设'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _loadPreset,
                        child: Text('加载预设'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }