import time
from typing import Callable, Any, Optional
import requests
from config import Config

def poll_until(
    action: Callable[[], Any],
    check: Callable[[Any], bool],
    interval: int = Config.POLL_INTERVAL,
    timeout: int = Config.POLL_TIMEOUT,
    description: str = "Polling...",
    on_retry: Optional[Callable[[Any], None]] = None
) -> Any:
    """
    Polls the action function until the check function returns True.
    Returns the result of action().
    Raises TimeoutError if timeout is reached.
    """
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            result = action()
            if check(result):
                return result
            
            if on_retry:
                on_retry(result)
        except Exception as e:
            # We might want to suppress transient errors or just log them
            pass
        
        time.sleep(interval)
    
    raise TimeoutError(f"Timed out waiting for: {description}")

def handle_request_error(response: requests.Response, context: str):
    """
    Raises a clean exception from a failed request.
    """
    try:
        data = response.json()
        error_msg = data.get("errorMessage") or data.get("error") or response.text
    except Exception:
        error_msg = response.text

    raise Exception(f"Error {context}: {response.status_code} - {error_msg}")
