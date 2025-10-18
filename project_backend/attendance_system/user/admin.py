from django.contrib import admin
from .models import AbsenceProposal, Student, Teacher, Classroom, Enrollment, AttendanceRecord

admin.site.register(Student)
admin.site.register(Teacher)
admin.site.register(Classroom)
admin.site.register(Enrollment)
admin.site.register(AttendanceRecord)
admin.site.register(AbsenceProposal)
