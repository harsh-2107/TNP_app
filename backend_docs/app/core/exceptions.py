#error lists hain yaahaan par


class StorageException(Exception):
    #Base exception - default

    def __init__(self, detail: str, status_code: int = 500) -> None:
        self.detail = detail
        self.status_code = status_code
        super().__init__(detail)


class FileNotFoundError_(StorageException):
    #file doesnt exists

    def __init__(self, detail: str = "File not found.") -> None:
        super().__init__(detail=detail, status_code=404)


class UnauthorizedFileAccess(StorageException):
    #file jo student ki HAI hi nahi

    def __init__(
        self, detail: str = "You do not have permission to access this file."
    ) -> None:
        super().__init__(detail=detail, status_code=403)


class InvalidFileType(StorageException):
   #File type galat hai

    def __init__(self, detail: str = "File type is not supported.") -> None:
        super().__init__(detail=detail, status_code=400)


class FileTooLarge(StorageException):
   #bahut bada hai

    def __init__(
        self, detail: str = "File exceeds the maximum allowed size."
    ) -> None:
        super().__init__(detail=detail, status_code=400)


class ProfileResumeLimitExceeded(StorageException):
    #Pehele hata fir lagaa

    def __init__(
        self, detail: str = "Profile resume limit reached."
    ) -> None:
        super().__init__(detail=detail, status_code=409)


class FileAlreadyUsed(StorageException):
    #File in use

    def __init__(
        self,
        detail: str = "File is referenced by an application and cannot be deleted.",
    ) -> None:
        super().__init__(detail=detail, status_code=409)


class R2OperationFailed(StorageException):
    #Cloudflare ka bhaang bhosdaa

    def __init__(self, detail: str = "Storage operation failed.") -> None:
        super().__init__(detail=detail, status_code=502)


class UploadNotFound(StorageException):
    #upload nahi mila

    def __init__(
        self, detail: str = "Upload not found or expired."
    ) -> None:
        super().__init__(detail=detail, status_code=404)


class InvalidShareToken(StorageException):
    #token expriry - application limit

    def __init__(
        self, detail: str = "Invalid or expired share link."
    ) -> None:
        super().__init__(detail=detail, status_code=404)
