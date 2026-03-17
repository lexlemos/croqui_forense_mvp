import 'package:share_plus/share_plus.dart';

void test() {
  SharePlus.instance.share(ShareParams(files: [XFile('a')], subject: 'b'));
}
