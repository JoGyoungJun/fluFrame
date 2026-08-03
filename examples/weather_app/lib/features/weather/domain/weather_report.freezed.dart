// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WeatherReport {

 double get temperatureC; double get windSpeedKmh;
/// Create a copy of WeatherReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherReportCopyWith<WeatherReport> get copyWith => _$WeatherReportCopyWithImpl<WeatherReport>(this as WeatherReport, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherReport&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.windSpeedKmh, windSpeedKmh) || other.windSpeedKmh == windSpeedKmh));
}


@override
int get hashCode => Object.hash(runtimeType,temperatureC,windSpeedKmh);

@override
String toString() {
  return 'WeatherReport(temperatureC: $temperatureC, windSpeedKmh: $windSpeedKmh)';
}


}

/// @nodoc
abstract mixin class $WeatherReportCopyWith<$Res>  {
  factory $WeatherReportCopyWith(WeatherReport value, $Res Function(WeatherReport) _then) = _$WeatherReportCopyWithImpl;
@useResult
$Res call({
 double temperatureC, double windSpeedKmh
});




}
/// @nodoc
class _$WeatherReportCopyWithImpl<$Res>
    implements $WeatherReportCopyWith<$Res> {
  _$WeatherReportCopyWithImpl(this._self, this._then);

  final WeatherReport _self;
  final $Res Function(WeatherReport) _then;

/// Create a copy of WeatherReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? temperatureC = null,Object? windSpeedKmh = null,}) {
  return _then(_self.copyWith(
temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,windSpeedKmh: null == windSpeedKmh ? _self.windSpeedKmh : windSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [WeatherReport].
extension WeatherReportPatterns on WeatherReport {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherReport() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherReport value)  $default,){
final _that = this;
switch (_that) {
case _WeatherReport():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherReport value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherReport() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double temperatureC,  double windSpeedKmh)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherReport() when $default != null:
return $default(_that.temperatureC,_that.windSpeedKmh);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double temperatureC,  double windSpeedKmh)  $default,) {final _that = this;
switch (_that) {
case _WeatherReport():
return $default(_that.temperatureC,_that.windSpeedKmh);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double temperatureC,  double windSpeedKmh)?  $default,) {final _that = this;
switch (_that) {
case _WeatherReport() when $default != null:
return $default(_that.temperatureC,_that.windSpeedKmh);case _:
  return null;

}
}

}

/// @nodoc


class _WeatherReport implements WeatherReport {
  const _WeatherReport({required this.temperatureC, required this.windSpeedKmh});
  

@override final  double temperatureC;
@override final  double windSpeedKmh;

/// Create a copy of WeatherReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherReportCopyWith<_WeatherReport> get copyWith => __$WeatherReportCopyWithImpl<_WeatherReport>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherReport&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.windSpeedKmh, windSpeedKmh) || other.windSpeedKmh == windSpeedKmh));
}


@override
int get hashCode => Object.hash(runtimeType,temperatureC,windSpeedKmh);

@override
String toString() {
  return 'WeatherReport(temperatureC: $temperatureC, windSpeedKmh: $windSpeedKmh)';
}


}

/// @nodoc
abstract mixin class _$WeatherReportCopyWith<$Res> implements $WeatherReportCopyWith<$Res> {
  factory _$WeatherReportCopyWith(_WeatherReport value, $Res Function(_WeatherReport) _then) = __$WeatherReportCopyWithImpl;
@override @useResult
$Res call({
 double temperatureC, double windSpeedKmh
});




}
/// @nodoc
class __$WeatherReportCopyWithImpl<$Res>
    implements _$WeatherReportCopyWith<$Res> {
  __$WeatherReportCopyWithImpl(this._self, this._then);

  final _WeatherReport _self;
  final $Res Function(_WeatherReport) _then;

/// Create a copy of WeatherReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? temperatureC = null,Object? windSpeedKmh = null,}) {
  return _then(_WeatherReport(
temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,windSpeedKmh: null == windSpeedKmh ? _self.windSpeedKmh : windSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
