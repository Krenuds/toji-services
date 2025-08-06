#!/usr/bin/env python3
"""
Test script for Piper TTS Service.

Simple integration tests to validate service functionality.
"""

import requests
import json
import time
import sys
from pathlib import Path


class PiperServiceTester:
    """Test client for Piper TTS Service."""
    
    def __init__(self, base_url="http://localhost:9001"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def test_health_check(self):
        """Test the health endpoint."""
        print("Testing health check...")
        try:
            response = self.session.get(f"{self.base_url}/health")
            response.raise_for_status()
            
            health_data = response.json()
            print(f"✓ Health check passed")
            print(f"  Status: {health_data['status']}")
            print(f"  Default voice: {health_data['default_voice']}")
            print(f"  Models loaded: {health_data['voice_models_loaded']}")
            return True
            
        except Exception as e:
            print(f"✗ Health check failed: {e}")
            return False
    
    def test_list_voices(self):
        """Test the voices endpoint."""
        print("\nTesting voice listing...")
        try:
            response = self.session.get(f"{self.base_url}/voices")
            response.raise_for_status()
            
            voices = response.json()
            print(f"✓ Voice listing passed")
            print(f"  Found {len(voices)} voices:")
            
            for voice in voices[:5]:  # Show first 5
                status = "✓" if voice["available"] else "✗"
                size = f"{voice['file_size_mb']}MB" if voice['file_size_mb'] else "Not downloaded"
                print(f"    {status} {voice['name']} ({voice['language']}, {voice['quality']}) - {size}")
            
            if len(voices) > 5:
                print(f"    ... and {len(voices) - 5} more")
            
            return True, voices
            
        except Exception as e:
            print(f"✗ Voice listing failed: {e}")
            return False, []
    
    def test_text_to_speech(self, text="Hello, this is a test of the Piper TTS service.", voice=None):
        """Test the TTS endpoint."""
        print(f"\nTesting text-to-speech...")
        print(f"  Text: '{text[:50]}...'")
        print(f"  Voice: {voice or 'default'}")
        
        try:
            tts_data = {"text": text}
            if voice:
                tts_data["voice"] = voice
            
            response = self.session.post(
                f"{self.base_url}/tts",
                json=tts_data,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            
            # Check response headers
            content_type = response.headers.get("content-type", "")
            content_length = len(response.content)
            
            if "audio/wav" in content_type and content_length > 0:
                print(f"✓ TTS generation passed")
                print(f"  Content-Type: {content_type}")
                print(f"  Audio size: {content_length} bytes")
                
                # Optionally save audio file for manual testing
                test_file = Path("test_output.wav")
                with open(test_file, "wb") as f:
                    f.write(response.content)
                print(f"  Audio saved to: {test_file}")
                
                return True
            else:
                print(f"✗ TTS generation failed: Invalid response format")
                print(f"  Content-Type: {content_type}")
                print(f"  Content length: {content_length}")
                return False
                
        except Exception as e:
            print(f"✗ TTS generation failed: {e}")
            return False
    
    def test_download_voice(self, voice_name="en_US-amy-low"):
        """Test voice download endpoint."""
        print(f"\nTesting voice download for {voice_name}...")
        try:
            response = self.session.post(
                f"{self.base_url}/download-voice",
                json={"voice_name": voice_name}
            )
            response.raise_for_status()
            
            result = response.json()
            print(f"✓ Download request accepted")
            print(f"  Status: {result['status']}")
            print(f"  Message: {result['message']}")
            
            return True
            
        except Exception as e:
            print(f"✗ Voice download failed: {e}")
            return False
    
    def run_all_tests(self):
        """Run complete test suite."""
        print("=" * 60)
        print("Piper TTS Service Test Suite")
        print("=" * 60)
        
        # Test health check first
        if not self.test_health_check():
            print("\n✗ Service appears to be down or unhealthy. Stopping tests.")
            return False
        
        # Test voice listing
        voices_ok, voices = self.test_list_voices()
        if not voices_ok:
            return False
        
        # Test TTS with default voice
        if not self.test_text_to_speech():
            return False
        
        # Test TTS with specific voice if available
        available_voices = [v for v in voices if v["available"]]
        if available_voices:
            test_voice = available_voices[0]["name"]
            if not self.test_text_to_speech(voice=test_voice):
                return False
        
        # Test voice download (optional)
        self.test_download_voice()
        
        print("\n" + "=" * 60)
        print("✓ All tests completed successfully!")
        print("=" * 60)
        
        return True


def main():
    """Main test function."""
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://localhost:9001"
    
    print(f"Testing Piper TTS Service at: {base_url}")
    print("Make sure the service is running before executing tests.")
    print()
    
    tester = PiperServiceTester(base_url)
    
    try:
        success = tester.run_all_tests()
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\nTests interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nUnexpected error during testing: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()