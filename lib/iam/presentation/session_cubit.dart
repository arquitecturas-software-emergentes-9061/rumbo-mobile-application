import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/session_facade.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this.facade) : super(facade.state) {
    facade.addListener(_changed);
  }
  final SessionFacade facade;
  void _changed() => emit(facade.state);
  Future<void> restore() => facade.restore();
  @override
  Future<void> close() {
    facade.removeListener(_changed);
    return super.close();
  }
}
