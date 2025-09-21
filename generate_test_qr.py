#!/usr/bin/env python3
"""
Simple QR Code Generator for Testing Attendance System
This script generates QR codes for different subjects that can be used to test the scanner.
"""

import qrcode
import os

def generate_qr_code(subject_name, output_dir="qr_codes"):
    """Generate a QR code for a subject name"""
    
    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Create QR code instance
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    
    # Add data (subject name)
    qr.add_data(subject_name)
    qr.make(fit=True)
    
    # Create an image from the QR Code instance
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Save the image
    filename = f"{output_dir}/{subject_name}_qr.png"
    img.save(filename)
    print(f"Generated QR code for '{subject_name}' -> {filename}")
    
    return filename

def main():
    """Generate QR codes for common subjects"""
    
    subjects = [
        "Maths",
        "science", 
        "English",
        "Physics",
        "Chemistry",
        "Biology",
        "History",
        "Geography"
    ]
    
    print("Generating QR codes for testing...")
    print("=" * 40)
    
    for subject in subjects:
        generate_qr_code(subject)
    
    print("=" * 40)
    print("QR codes generated successfully!")
    print("\nInstructions:")
    print("1. Print or display these QR codes on a screen")
    print("2. Use the student app to scan them")
    print("3. The QR code should contain just the subject name (e.g., 'Maths')")
    print("4. Make sure the QR code is at least 2x2 cm when printed")

if __name__ == "__main__":
    main()
