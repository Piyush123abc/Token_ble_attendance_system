# attendance_session/urls.py
from django.urls import path
from .views import (
    StartSessionView,
    PassTokenView,
    AddExceptionView,
    GetExceptionListView,
    MarkExceptionPresentView,
    FinalizeSessionView,
    ActiveSessionsView,
    ClassroomSessionStatusView
)
#path('session/', include('attendance_session.urls')),
urlpatterns = [
    # ---------------------------
    # Teacher-only endpoints
    # ---------------------------
    # Start attendance session for a classroom
    path('teacher/classroom/<int:classroom_id>/start/', StartSessionView.as_view(), name='start-session'),

    # Get current exception list for classroom
    path('teacher/classroom/<int:classroom_id>/exceptions/', GetExceptionListView.as_view(), name='get-exception-list'),

    # Mark students present (from exception or otherwise)
    path('teacher/classroom/<int:classroom_id>/mark-present/', MarkExceptionPresentView.as_view(), name='mark-present'),

    # Finalize attendance session
    path('teacher/classroom/<int:classroom_id>/finalize/', FinalizeSessionView.as_view(), name='finalize-session'),

    # List all active sessions
    path('teacher/sessions/active/', ActiveSessionsView.as_view(), name='active-sessions'),

    # ---------------------------
    # Student-only endpoints
    # ---------------------------
    # Pass token to another student
    path('student/classroom/<int:classroom_id>/pass-token/', PassTokenView.as_view(), name='pass-token'),

    # Add self to exception list
    path('student/classroom/<int:classroom_id>/exception/', AddExceptionView.as_view(), name='add-exception'),
    
    #check activeness of the session for a classromm
    path("student/classroom/<int:classroom_id>/session/",ClassroomSessionStatusView.as_view(),name="classroom-session-status"),
    
    #check if the classroom has an active session
    path('session/status/<int:classroom_id>/', ClassroomSessionStatusView.as_view(), name='classroom-session-status'),
]


