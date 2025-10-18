# attendance_session/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.utils import timezone
from user.models import Student, Teacher, Classroom, AttendanceRecord
from user.permission import IsTeacher, IsStudent

# ---------------------------
# Session storage (in-memory)
# ---------------------------
# Key: classroom_id
# Value: SessionObject instance
sessions = {}

# ---------------------------
# Node & Disjoint Set (Union-Find) Objects
# ---------------------------
class Node:
    """Represents a student or teacher in the attendance session using union-find for token passing."""
    def __init__(self, uid):
        self.uid = uid          # Unique identifier of student/teacher
        self.parent = self      # Initially, parent is self (disjoint set root)
        self.rank = 0           # Rank for union by rank optimization

    def find(self):
        """Find the ultimate parent of this node (with path compression)."""
        if self.parent != self:
            self.parent = self.parent.find()
        return self.parent
    def union(self, other):
        """Union two nodes so teacher always remains root if involved."""
        root1 = self.find()
        root2 = other.find()

        # Always make teacher the root if one is teacher
        if 'T' in root1.uid:  # teacher UID prefix
            root2.parent = root1
            return
        if 'T' in root2.uid:
            root1.parent = root2
            return

        # Normal union by rank for students
        if root1.rank > root2.rank:
            root2.parent = root1
        else:
            root1.parent = root2
            if root1.rank == root2.rank:
                root2.rank += 1


class SessionObject:
    """Represents an active attendance session for a classroom."""
    def __init__(self, classroom_id, teacher_uid, student_uids):
        self.classroom_id = classroom_id
        self.teacher_uid = teacher_uid
        # Create Node objects for each student
        self.nodes = {uid: Node(uid) for uid in student_uids}
        # Create Node for teacher and add to nodes
        self.teacher_node = Node(teacher_uid)
        self.nodes[teacher_uid] = self.teacher_node
        # Students without devices (exception list)
        self.exception_list = set()

    # ---------------------------
    # Token Passing Logic
    # ---------------------------
    def pass_token(self, from_uid, to_uid):
        """
        Merge sender and receiver nodes to form a linked group.
        Simulates student A passing token to B.
        """
        if from_uid not in self.nodes or to_uid not in self.nodes:
            raise ValueError("Invalid from_uid or to_uid")
        self.nodes[from_uid].union(self.nodes[to_uid])

    # ---------------------------
    # Exception Handling
    # ---------------------------
    def add_exception(self, student_uid):
        """Add a student to exception list (no device)."""
        if student_uid not in self.nodes:
            raise ValueError("Invalid student UID")
        self.exception_list.add(student_uid)

    def get_exception_list(self):
        """Return the current exception list."""
        return list(self.exception_list)

    # ---------------------------
    # Finalize Attendance
    # ---------------------------
    def finalize_attendance(self, present_uids_from_exception=[]):
        """
        Mark attendance at session end.
        - Students in exception list marked present by teacher are linked to teacher node.
        - Any node whose ultimate parent is teacher → present; otherwise → absent.
        """
        # Link present exception students to teacher
        for uid in present_uids_from_exception:
            if uid in self.exception_list:
                self.nodes[uid].union(self.teacher_node)

        attendance = {}
        # Iterate all nodes, mark present if linked to teacher
        for uid, node in self.nodes.items():
            if uid == self.teacher_uid:
                continue  # Skip teacher node
            attendance[uid] = node.find() == self.teacher_node
        return attendance

# ---------------------------
# Teacher-only Endpoints
# ---------------------------
class StartSessionView(APIView):
    """Teacher starts attendance session for a classroom."""
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def post(self, request, classroom_id):
        teacher_uid = request.user.teacher.uid

        if classroom_id in sessions:
            return Response({"error": "Session already active"}, status=status.HTTP_400_BAD_REQUEST)

        # Fetch classroom
        try:
            classroom = Classroom.objects.get(id=classroom_id)
        except Classroom.DoesNotExist:
            return Response({"error": "Classroom not found"}, status=status.HTTP_404_NOT_FOUND)

        # Initialize session with all student UIDs
        student_uids = list(classroom.enrollments.all().values_list('student__uid', flat=True))
        session = SessionObject(classroom_id, teacher_uid, student_uids)
        sessions[classroom_id] = session
        return Response({"message": f"Session started for classroom {classroom_id}"})

class PassTokenView(APIView):
    """Student passes token to another student (A -> B)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, classroom_id):
        from_uid = request.data.get("from_uid")
        to_uid = request.data.get("to_uid")

        print(f"[DEBUG] PassToken called: from_uid={from_uid}, to_uid={to_uid}")

        if not from_uid or not to_uid:
            print("[DEBUG] Missing from_uid or to_uid")
            return Response({"error": "from_uid and to_uid required"}, status=status.HTTP_400_BAD_REQUEST)

        session = sessions.get(classroom_id)
        if not session:
            print(f"[DEBUG] No active session for classroom {classroom_id}")
            return Response({"error": "No active session"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            session.pass_token(from_uid, to_uid)
            print(f"[DEBUG] Nodes after pass_token:")
            for uid, node in session.nodes.items():
                parent_uid = node.find().uid
                print(f"   {uid} -> parent: {parent_uid}")
            return Response({"message": f"Token passed {from_uid} -> {to_uid}"})
        except ValueError as e:
            print(f"[DEBUG] Error in pass_token: {str(e)}")
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)



class ClassroomSessionStatusView(APIView):
    """
    Check if a specific classroom has an active attendance session.
    """
    permission_classes = [permissions.IsAuthenticated, IsStudent]

    def get(self, request, classroom_id):
        if classroom_id in sessions:
            return Response({"active": True, "message": "Attendance session is active"})
        else:
            return Response({"active": False, "message": "No active attendance session"}, status=status.HTTP_200_OK)


class AddExceptionView(APIView):
    """student adds a student to the exception list by UID."""
    permission_classes = [permissions.IsAuthenticated] 

    def post(self, request, classroom_id):
        # Take UID from request body
        student_uid = request.data.get("uid")
        if not student_uid:
            return Response(
                {"error": "UID is required. Please provide a valid student UID."},
                status=status.HTTP_400_BAD_REQUEST
            )

        session = sessions.get(classroom_id)
        if not session:
            return Response(
                {"error": f"No active attendance session found for classroom {classroom_id}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            session.add_exception(student_uid)
        except Exception as e:
            return Response(
                {"error": f"Failed to add student {student_uid} to exception list: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )

        return Response(
            {"message": f"Student {student_uid} successfully added to exception list."},
            status=status.HTTP_200_OK
        )

class GetExceptionListView(APIView):
    """Teacher fetches exception list for classroom (UID + username)."""
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def get(self, request, classroom_id):
        session = sessions.get(classroom_id)
        if not session:
            return Response({"error": "No active session"}, status=status.HTTP_400_BAD_REQUEST)

        exception_uids = session.get_exception_list()
        students = Student.objects.filter(uid__in=exception_uids).select_related('user')

        exception_list = [
            {"uid": student.uid, "username": student.user.username}
            for student in students
        ]

        return Response({"exception_list": exception_list})

# class GetExceptionListView(APIView):
#     """Teacher fetches exception list for classroom."""
#     permission_classes = [permissions.IsAuthenticated, IsTeacher]

#     def get(self, request, classroom_id):
#         session = sessions.get(classroom_id)
#         if not session:
#             return Response({"error": "No active session"}, status=status.HTTP_400_BAD_REQUEST)
#         return Response({"exception_list": session.get_exception_list()})




class MarkExceptionPresentView(APIView):
    """
    Teacher marks students present for the session (from exception or otherwise).
    The UIDs sent here will be unioned to the teacher's node.
    """
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def post(self, request, classroom_id):
        present_uids = request.data.get("present_uids", [])
        if not present_uids:
            return Response({"error": "No UIDs provided"}, status=status.HTTP_400_BAD_REQUEST)

        session = sessions.get(classroom_id)
        if not session:
            return Response({"error": "No active session"}, status=status.HTTP_400_BAD_REQUEST)

        # Get all student UIDs in this classroom
        try:
            classroom = Classroom.objects.get(id=classroom_id)
        except Classroom.DoesNotExist:
            return Response({"error": "Classroom not found"}, status=status.HTTP_404_NOT_FOUND)

        enrolled_uids = set(classroom.enrollments.all().values_list('student__uid', flat=True))

        # Only allow UIDs that exist in the classroom
        for uid in present_uids:
            if uid not in enrolled_uids:
                return Response({"error": f"UID {uid} not enrolled in this classroom"}, status=status.HTTP_400_BAD_REQUEST)
            # Union student node with teacher node
            session.nodes[uid].union(session.teacher_node)

        return Response({"message": f"{len(present_uids)} students marked present"})



class FinalizeSessionView(APIView):
    """Teacher finalizes attendance session and returns attendance summary."""
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def post(self, request, classroom_id):
        present_uids_from_exception = request.data.get("present_uids", [])
        print(f"[DEBUG] FinalizeSession called with present_uids_from_exception={present_uids_from_exception}")

        session = sessions.get(classroom_id)
        if not session:
            print(f"[DEBUG] No active session for classroom {classroom_id}")
            return Response({"error": "No active session"}, status=status.HTTP_400_BAD_REQUEST)

        # Fetch classroom
        try:
            classroom = Classroom.objects.get(id=classroom_id)
        except Classroom.DoesNotExist:
            print(f"[DEBUG] Classroom {classroom_id} not found")
            return Response({"error": "Classroom not found"}, status=status.HTTP_404_NOT_FOUND)

        # Compute attendance
        results = session.finalize_attendance(present_uids_from_exception)
        print("[DEBUG] Attendance results:")
        for uid, is_present in results.items():
            print(f"   {uid}: {'PRESENT' if is_present else 'ABSENT'}")

        today = timezone.now().date()

        # Save attendance in DB
        for uid, is_present in results.items():
            student = Student.objects.get(uid=uid)
            AttendanceRecord.objects.create(
                student=student,
                classroom=classroom,
                date=today,
                status="PRESENT" if is_present else "ABSENT"
    )

        # Remove session from memory
        del sessions[classroom_id]
        print(f"[DEBUG] Session for classroom {classroom_id} removed from memory")

        # --- Attendance summary ---
        total_students = classroom.enrollments.count()
        total_present = sum(1 for status in results.values() if status)
        total_absent = total_students - total_present

        print(f"[DEBUG] Summary: total_students={total_students}, present={total_present}, absent={total_absent}")

        return Response({
            "message": f"Attendance finalized for classroom {classroom_id}",
            "summary": {
                "total_students": total_students,
                "present": total_present,
                "absent": total_absent,
            }
        })

class ActiveSessionsView(APIView):
    """Teacher can see all active sessions (debugging / monitoring)."""
    permission_classes = [permissions.IsAuthenticated, IsTeacher]

    def get(self, request):
        return Response({"active_sessions": list(sessions.keys())})


# ---------------------------
# Check if classroom has active session
# ---------------------------
class ClassroomSessionStatusView(APIView):
    """
    Check if a specific classroom has an active attendance session.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, classroom_id):
        if classroom_id in sessions:
            return Response({"active": True, "message": "Attendance session is active"})
        else:
            return Response({"active": False, "message": "No active attendance session"}, status=status.HTTP_200_OK)
