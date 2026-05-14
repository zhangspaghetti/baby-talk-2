import os
import glob
import re

def process_all_files(directory):
    dart_files = glob.glob(f'{directory}/**/*.dart', recursive=True)
    for f_path in dart_files:
        with open(f_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        original_content = content
        
        content = re.sub(r'ViewModel', 'Notifier', content)
        content = re.sub(r'view_model', 'notifier', content)
        content = re.sub(r'\bviewModel\b', 'notifier', content)
        
        if content != original_content:
            with open(f_path, 'w', encoding='utf-8') as f:
                f.write(content)

if __name__ == '__main__':
    process_all_files('integration_test')
    process_all_files('test')
    print("Done replacing in tests.")
