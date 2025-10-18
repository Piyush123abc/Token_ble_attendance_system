"""
URL configuration for attendance_system project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.conf import settings
from django.conf.urls.static import static
# Simple view for base URL check
def base_url_response(request):
    return JsonResponse({"message": "Backend is running!"})

urlpatterns = [
    
    path('admin/', admin.site.urls),
    
 # Base URL response
    path('', base_url_response, name='base-url'),

    # User app (students, teachers, classrooms, enrollments, etc.)
    path('user/', include('user.urls')),

    # Attendance session app (token passing, exceptions, finalize attendance)
    path('session/', include('attendance_session.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)