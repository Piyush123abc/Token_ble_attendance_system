from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

from .views import (
    CreateAbsenceProposalView,
    StudentAbsenceProposalListView,
    StudentClassroomSearchAPIView,
    StudentRegisterView,
    TeacherPendingProposalsView,
    TeacherRegisterView,
    EnrollmentCreateView,
    StudentEnrollmentListView,
    StudentAttendanceListView,
    TeacherClassroomViewSet,
    ProfileView,
    TeacherUpdateProposalView,
)
from .views import ClassroomSearchView

#  path('user/', include('user.urls')),
# Router for teacher classroom viewset
# -------------------------------------------------------------------
# Django REST Framework automatically generates these routes for
# TeacherClassroomViewSet via DefaultRouter:
#
# HTTP Method | URL                            | Action
# ------------------------------------------------------------
# GET         | /teacher/classrooms/           | List all classrooms of the logged-in teacher  -> list()
# POST        | /teacher/classrooms/           | Create a new classroom                        -> create()
# GET         | /teacher/classrooms/<id>/      | Retrieve a specific classroom                 -> retrieve()
# PUT         | /teacher/classrooms/<id>/      | Update a classroom (replace all fields)       -> update()
# PATCH       | /teacher/classrooms/<id>/      | Partially update a classroom (some fields)    -> partial_update()
# DELETE      | /teacher/classrooms/<id>/      | Delete a classroom                            -> destroy()
# -------------------------------------------------------------------

router = DefaultRouter()
router.register(r'teacher/classrooms', TeacherClassroomViewSet, basename='teacher-classrooms')

urlpatterns = [
    # Registration
    path('register/student/', StudentRegisterView.as_view(), name='student-register'),
    path('register/teacher/', TeacherRegisterView.as_view(), name='teacher-register'),

    # JWT Login + Refresh
    path('login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('login/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Student enrollment & attendance
    path('student/enroll/', EnrollmentCreateView.as_view(), name='student-enroll'),
    path('student/enrollments/', StudentEnrollmentListView.as_view(), name='student-enrollments'),
    path('student/attendance/', StudentAttendanceListView.as_view(), name='student-attendance'),
    path('student/search-classroom/', ClassroomSearchView.as_view(), name='student-search-classroom'),
    path('student/classrooms/', StudentClassroomSearchAPIView.as_view(), name='student-classroom-search'),


    # Profile (read-only)
    path('profile/', ProfileView.as_view(), name='profile'),

    # Include router for teacher classrooms
    path('', include(router.urls)),
    
    path('absence-proposals/create/', CreateAbsenceProposalView.as_view(), name='create-absence-proposal'),
    path('absence-proposals/list/', StudentAbsenceProposalListView.as_view(), name='list-absence-proposals'),
    path('teacher/absence-proposals/pending/', TeacherPendingProposalsView.as_view(), name='teacher-pending-proposals'),
    path('teacher/absence-proposal/<int:id>/update/', TeacherUpdateProposalView.as_view(), name='teacher-update-proposal'),

]
