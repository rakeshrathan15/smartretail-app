import 'package:flutter_test/flutter_test.dart';
import 'package:smart_retail_app/router.dart';

String? redirect(String location, {bool loading = false, bool signedIn = false, bool shopProfileComplete = true}) =>
    authRedirect(
      loading: loading,
      signedIn: signedIn,
      uri: Uri.parse(location),
      shopProfileComplete: shopProfileComplete,
    );

void main() {
  test('a link opened while the session loads is kept and opened afterwards', () {
    final toSplash = redirect('/product/thums-up', loading: true);
    expect(toSplash, '/splash?from=%2Fproduct%2Fthums-up');
    expect(redirect(toSplash!, loading: true), isNull);
    expect(redirect(toSplash, signedIn: true), '/product/thums-up');
  });

  test('a link opened while signed out is opened after signing in', () {
    expect(redirect('/splash?from=%2Fshop%3Fcategory%3Dcolas'), '/login?from=%2Fshop%3Fcategory%3Dcolas');
    expect(redirect('/login?from=%2Fshop%3Fcategory%3Dcolas'), isNull);
    expect(redirect('/login?from=%2Fshop%3Fcategory%3Dcolas', signedIn: true), '/shop?category=colas');
    expect(redirect('/orders'), '/login?from=%2Forders');
  });

  test('defaults to home and ignores links that leave the app', () {
    expect(redirect('/splash?from=%2Fhome', signedIn: true), '/home');
    expect(redirect('/login', signedIn: true), '/home');
    expect(redirect('/splash?from=%2F%2Fevil.example', signedIn: true), '/home');
    expect(redirect('/splash?from=https%3A%2F%2Fevil.example', signedIn: true), '/home');
    expect(redirect('/home'), '/login');
    expect(redirect('/cart', signedIn: true), isNull);
  });

  test('a new account fills in its shop profile, then continues', () {
    expect(redirect('/register', signedIn: true, shopProfileComplete: false), '/shop-profile?from=%2Fhome');
    expect(redirect('/register?from=%2Fcart', signedIn: true, shopProfileComplete: false), '/shop-profile?from=%2Fcart');
    // Signing in to an existing account is not interrupted.
    expect(redirect('/login', signedIn: true, shopProfileComplete: false), '/home');
    expect(redirect('/shop-profile?from=%2Fhome', signedIn: true, shopProfileComplete: false), isNull);
  });
}
