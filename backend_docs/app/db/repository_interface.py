#file storage ke liye repo interface
#Supabase wale ka kaam
#sotrage module bas issi interface ko import kregi, na ki supabase sdk ko


from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


@dataclass
class FileRecord:
    #row in student_files table
    #attributes me aata hai UUID, student id, object key of R2, original filename, mime type, size, is profile_resume, created at

    

    id: str
    student_id: str
    object_key: str
    filename: str
    mime_type: str
    size_bytes: int
    file_type: str
    is_profile_file: bool
    used_for_application: bool
    created_at: datetime
    is_default: bool = False


class FileRepositoryInterface(ABC):
    #all methods async to support async database
   

    @abstractmethod
    async def create_file_record(
        self,
        *,
        file_id: str,
        student_id: str,
        object_key: str,
        filename: str,
        mime_type: str,
        size_bytes: int,
        file_type: str,
        is_profile_file: bool,
        used_for_application: bool,
    ) -> FileRecord:
        #call only after R2 upload has been verified trhogu heead request
        
        ...

    @abstractmethod
    async def get_file_by_id(self, file_id: str) -> FileRecord | None:
        #Fetch a single file record by its primary key.

        
        ...

    @abstractmethod
    async def get_student_file(
        self, file_id: str, student_id: str
    ) -> FileRecord | None:
        #Fetch a file record only if it belongs to the given student.

        
        ...

    @abstractmethod
    async def get_profile_files(self, student_id: str) -> list[FileRecord]:
        #List all profile files (resumes and cover letters) for a student.

        
        ...

    @abstractmethod
    async def count_profile_resumes(self, student_id: str) -> int:
        #Count the number of profile resumes for a student.
        ...

    @abstractmethod
    async def count_profile_cover_letters(self, student_id: str) -> int:
        # Count the number of profile cover letters for a student.
        ...

    @abstractmethod
    async def update_profile_status(self, file_id: str, is_profile_file: bool) -> None:
        #Update the is_profile_file status of a file record.
        ...

    @abstractmethod
    async def mark_file_used_for_application(self, file_id: str) -> None:
        # Set used_for_application = True for a file record.
        ...

    @abstractmethod
    async def delete_file_record(self, file_id: str) -> None:
        # Hard-delete a file record from the student_files table.

        # thi should ONLY be called after the R2 object has been
        # deleted.

       
        ...

    @abstractmethod
    async def get_file_by_share_token_hash(
        self, token_hash: str
    ) -> FileRecord | None:
        # Look up a file using a hashed share token.

        #SHA256
        ...

    @abstractmethod
    async def store_share_token(self, file_id: str, token_hash: str) -> None:
       
        ...

    @abstractmethod
    async def set_default_resume(self, student_id: str, file_id: str) -> None:
        # Mark a file as the student's default resume.

       
        ...
