import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calm_space/screens/register/register_screen.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  UserCredential,
  User,
  CollectionReference,
  DocumentReference,
])
import 'register_screen_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    mockCollectionRef = MockCollectionReference();
    mockDocRef = MockDocumentReference();

    when(mockFirestore.collection('users')).thenReturn(mockCollectionRef);
    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    when(mockDocRef.set(any)).thenAnswer((_) async => {});
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: RegisterScreen(
        auth: mockAuth,
        firestore: mockFirestore,
      ),
    );
  }

  group('RegisterScreen Tests', () {
    testWidgets('Validación falla si los campos están vacíos', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap button
      await tester.tap(find.text('Registrarse'));
      await tester.pump();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
    });

    testWidgets('Muestra SnackBar rojo si Firebase Auth lanza error', (WidgetTester tester) async {
      when(mockAuth.createUserWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      await tester.pumpWidget(createWidgetUnderTest());

      // Llenar campos (Name, Email, Password)
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      // Tocar botón
      await tester.tap(find.text('Registrarse'));
      await tester.pump(); // Inicia carga
      await tester.pumpAndSettle(); // Termina carga y muestra snackbar

      expect(find.text('Ya existe una cuenta con este correo.'), findsOneWidget);
    });

    testWidgets('Registro completo y mostrado mensaje de éxito', (WidgetTester tester) async {
      when(mockAuth.createUserWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenAnswer((_) async => mockUserCredential);
          
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('fake-uid');
      when(mockUser.email).thenReturn('test@test.com');
      when(mockUser.updateDisplayName(any)).thenAnswer((_) async => {});

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.text('¡Cuenta creada con éxito! Bienvenido a CalmSpace'), findsOneWidget);
    });
  });
}
