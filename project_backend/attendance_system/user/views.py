from rest_framework import generics, viewsets, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import AbsenceProposal, Student, Teacher, Classroom, Enrollment, AttendanceRecord
from .serializer import (
    AbsenceProposalSerializer,
    StudentSerializer,
    TeacherSerializer,
    ClassroomSerializer,
    EnrollmentSerializer,
    AttendanceRecordSerializer
)
from .permission import IsStudent, IsTeacher
from rest_framework import status
from django.shortcuts import get_object_or_404
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt



# ------------------------------
# Registration Views
# ------------------------------

class StudentRegisterView(generics.CreateAPIView):
    serializer_class = StudentSerializer
    permission_classes = [permissions.AllowAny]


class TeacherRegisterView(generics.CreateAPIView):
    serializer_class = TeacherSerializer
    permission_classes = [permissions.AllowAny]


# ------------------------------
# Student Views
# ------------------------------
class EnrollmentCreateView(generics.CreateAPIView):
    serializer_class = EnrollmentSerializer
    permission_classes = [permissions.IsAuthenticated, IsStudent]

    def perform_create(self, serializer):
        student = Student.objects.get(user=self.request.user)
        serializer.save(student=student)


class StudentEnrollmentListView(generics.ListAPIView):
    serializer_class = ClassroomSerializer
    permission_classes = [permissions.IsAuthenticated, IsStudent]

    def get_queryset(self):
        student = Student.objects.get(user=self.request.user)
        return Classroom.objects.filter(enrollments__student=student)


class StudentAttendanceListView(generics.ListAPIView):
    serializer_class = AttendanceRecordSerializer
    permission_classes = [permissions.IsAuthenticated, IsStudent]

    def get_queryset(self):
        student = Student.objects.get(user=self.request.user)
        classroom_id = self.request.query_params.get("classroom_id")
        if classroom_id:
            return AttendanceRecord.objects.filter(student=student, classroom_id=classroom_id)
        return AttendanceRecord.objects.filter(student=student)


class ClassroomSearchView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsStudent]

    def get(self, request):
        code = request.query_params.get("code")
        if not code:
            return Response({"error": "Classroom code is required"}, status=status.HTTP_400_BAD_REQUEST)

        code = code.strip()

        if code.lower() == "all":
            # Return all classrooms
            classrooms = Classroom.objects.all()
            serializer = ClassroomSerializer(classrooms, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        # Partial or exact case-insensitive search
        classrooms = Classroom.objects.filter(code__icontains=code)
        if not classrooms.exists():
            return Response({"error": "No classrooms found"}, status=status.HTTP_404_NOT_FOUND)

        serializer = ClassroomSerializer(classrooms, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    
class StudentClassroomSearchAPIView(APIView):
  #  permission_classes = [permissions.IsAuthenticated]  # or custom IsStudent

    def get(self, request):
        """
        GET /student/classrooms/?code=XYZ
        Returns classrooms whose code contains the search string.
        """
        code_query = request.query_params.get('code')
        if not code_query:
            return Response({"error": "Please provide a 'code' query parameter."}, status=status.HTTP_400_BAD_REQUEST)

        classrooms = Classroom.objects.filter(code__icontains=code_query)  # only active classrooms
        serializer = ClassroomSerializer(classrooms, many=True)
        return Response(serializer.data)
    
    
# ------------------------------
# Teacher Views
# ------------------------------
class TeacherClassroomViewSet(viewsets.ModelViewSet):
    serializer_class = ClassroomSerializer
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def get_queryset(self):
        teacher = Teacher.objects.get(user=self.request.user)
        return Classroom.objects.filter(teacher=teacher)

    def perform_create(self, serializer):
        teacher = Teacher.objects.get(user=self.request.user)
        serializer.save(teacher=teacher)
# This single ViewSet automatically handles all CRUD operations
# (list, retrieve, create, update, partial_update, destroy)


# ------------------------------
# Profile View (Read-only)
# ------------------------------
class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            student = Student.objects.get(user=request.user)
            serializer = StudentSerializer(student)
        except Student.DoesNotExist:
            teacher = Teacher.objects.get(user=request.user)
            serializer = TeacherSerializer(teacher)
        return Response(serializer.data)


class CreateAbsenceProposalView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        # Get student object from logged-in user
        try:
            student = Student.objects.get(user=request.user)
        except Student.DoesNotExist:
            return Response({"error": "Student profile not found."}, status=status.HTTP_400_BAD_REQUEST)

        # Validate required fields manually
        required_fields = ['reason_type', 'reason_description', 'start_datetime', 'end_datetime']
        missing_fields = [f for f in required_fields if not request.data.get(f)]
        if missing_fields:
            return Response({f: "This field is required." for f in missing_fields}, status=status.HTTP_400_BAD_REQUEST)

        # Create proposal with student from auth
        serializer = AbsenceProposalSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            proposal = serializer.save(student=student)  # assign student here

            # Update related AttendanceRecords to PENDING
            start_dt = serializer.validated_data['start_datetime']
            end_dt = serializer.validated_data['end_datetime']

            AttendanceRecord.objects.filter(
                student=student,
                timestamp__gte=start_dt,
                timestamp__lte=end_dt
            ).update(status="PENDING")

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        
        

class StudentAbsenceProposalListView(APIView):
    """
    List all absence proposals of the logged-in student, most recent first.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            student = Student.objects.get(user=request.user)
        except Student.DoesNotExist:
            return Response({"error": "Student profile not found."}, status=status.HTTP_400_BAD_REQUEST)

        proposals = AbsenceProposal.objects.filter(student=student).order_by('-timestamp')
        serializer = AbsenceProposalSerializer(proposals, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    
            
class TeacherPendingProposalsView(generics.ListAPIView):
    """
    Returns all pending absence proposals from students in classrooms taught by the logged-in teacher.
    """
    serializer_class = AbsenceProposalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Ensure user is a teacher
        teacher = getattr(self.request.user, "teacher", None)
        if not teacher:
            return AbsenceProposal.objects.none()

        # Get classrooms taught by this teacher
        classrooms = Classroom.objects.filter(teacher=teacher)

        # Return pending proposals from those classrooms
        return AbsenceProposal.objects.filter(
            student__enrollments__classroom__in=classrooms,
            status="PENDING"
        ).distinct()
        
        


class TeacherUpdateProposalView(generics.UpdateAPIView):
    """
    Teacher can approve or reject a student absence proposal.
    """
    queryset = AbsenceProposal.objects.all()
    serializer_class = AbsenceProposalSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'  # pass proposal id in URL

    def patch(self, request, *args, **kwargs):
        proposal = self.get_object()
        teacher = getattr(request.user, "teacher", None)
        if not teacher:
            return Response({"detail": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)

        # Ensure teacher owns the classroom(s) of the student
        student_classrooms = [enrollment.classroom for enrollment in proposal.student.enrollments.all()]
        if not any(c.teacher == teacher for c in student_classrooms):
            return Response({"detail": "Not authorized for this student"}, status=status.HTTP_403_FORBIDDEN)

        action = request.data.get("status")
        if action not in ["APPROVED", "REJECTED"]:
            return Response({"detail": "Invalid action, must be APPROVED or REJECTED"}, status=status.HTTP_400_BAD_REQUEST)

        # Update proposal status
        proposal.status = action
        proposal.save()

        # Update attendance records in the exact time range using timestamp
        records = AttendanceRecord.objects.filter(
            student=proposal.student,
            timestamp__gte=proposal.start_datetime,
            timestamp__lte=proposal.end_datetime
        )

        if action == "APPROVED":
            records.update(status="PRESENT")
        else:
            records.update(status="ABSENT")

        serializer = self.get_serializer(proposal)
        return Response(serializer.data, status=status.HTTP_200_OK)
