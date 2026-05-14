import os
import glob
import re

def process_view_models():
    # Find all view model files
    vm_files = glob.glob('lib/**/*_view_model.dart', recursive=True)
    
    for vm_file in vm_files:
        notifier_file = vm_file.replace('_view_model.dart', '_notifier.dart')
        
        with open(vm_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Replace ViewModel with Notifier in the content
        new_content = re.sub(r'ViewModel', 'Notifier', content)
        new_content = re.sub(r'view_model', 'notifier', new_content)
        new_content = re.sub(r'viewModel', 'notifier', new_content)
        
        # Write to notifier file
        with open(notifier_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
            
        # Tombstone the view model file
        basename = os.path.basename(notifier_file)
        with open(vm_file, 'w', encoding='utf-8') as f:
            f.write(f"export '{basename}';\n")

def process_all_files():
    dart_files = glob.glob('lib/**/*.dart', recursive=True)
    for f_path in dart_files:
        # Skip the view model files since we just tombstoned them
        if f_path.endswith('_view_model.dart'):
            continue
            
        with open(f_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        original_content = content
        
        # Replace ViewModel -> Notifier
        content = re.sub(r'ViewModel', 'Notifier', content)
        # Replace view_model -> notifier
        content = re.sub(r'view_model', 'notifier', content)
        # Replace viewModel -> notifier (only when it's a variable name, like `viewModel.` or `viewModel =`)
        # To avoid renaming something unrelated, we just replace exact matches of 'viewModel'
        content = re.sub(r'\bviewModel\b', 'notifier', content)
        
        if content != original_content:
            with open(f_path, 'w', encoding='utf-8') as f:
                f.write(content)

if __name__ == '__main__':
    process_view_models()
    process_all_files()
    print("Done replacing ViewModels.")
