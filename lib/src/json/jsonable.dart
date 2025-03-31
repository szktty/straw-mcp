/// JSONにシリアライズ可能なオブジェクトを表すインターフェース
///
/// このインターフェースを実装するクラスは、JSONオブジェクトに変換可能であることを示します。
abstract class Jsonable {
  /// オブジェクトをJSONマップに変換する
  ///
  /// このメソッドはオブジェクトの状態をJSONにシリアライズ可能な
  /// Map<String, dynamic>形式で返します。
  Map<String, dynamic> toJson();
}
