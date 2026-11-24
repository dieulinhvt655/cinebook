import 'package:cinebook/core/network/media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relative media paths are joined to the API base, others kept', () {
    const base = 'https://api.example.dev/api/v1';
    expect(
      resolveMediaUrl('/media/posters/a.jpg', base: base),
      'https://api.example.dev/api/v1/media/posters/a.jpg',
    );
    expect(
      resolveMediaUrl('/media/a.jpg', base: '$base/'),
      'https://api.example.dev/api/v1/media/a.jpg',
    );
    expect(
      resolveMediaUrl('https://res.cloudinary.com/x.jpg', base: base),
      'https://res.cloudinary.com/x.jpg',
    );
    expect(resolveMediaUrl(null, base: base), isNull);
    expect(resolveMediaUrl('', base: base), isNull);
  });
}
