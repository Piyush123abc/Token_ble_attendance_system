from rest_framework.permissions import BasePermission
from .models import Teacher, Student


class IsTeacher(BasePermission):
    """
    Allows access only to users who are Teachers.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and Teacher.objects.filter(user=request.user).exists()


class IsStudent(BasePermission):
    """
    Allows access only to users who are Students.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and Student.objects.filter(user=request.user).exists()


class IsTeacherOrStudent(BasePermission):
    """
    Allows access if user is either Teacher or Student.
    """
    def has_permission(self, request, view):
        return (
            request.user 
            and request.user.is_authenticated 
            and (Teacher.objects.filter(user=request.user).exists() 
                 or Student.objects.filter(user=request.user).exists())
        )
