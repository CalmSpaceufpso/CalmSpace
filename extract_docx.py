import zipfile
import xml.etree.ElementTree as ET

def extract(path):
    with zipfile.ZipFile(path) as z:
        xml = z.read('word/document.xml')
        tree = ET.fromstring(xml)
        out = []
        for elem in tree.iter():
            if elem.tag.endswith('t') and elem.text:
                out.append(elem.text)
        return '\n'.join(out)

text = extract(r'c:\Users\soyba\OneDrive\Escritorio\CalmSpace\CalmSpace\Backlog_Epicas_HU_Tareas (1) (1).docx')
with open(r'c:\Users\soyba\OneDrive\Escritorio\CalmSpace\CalmSpace\docx_content.txt', 'w', encoding='utf-8') as f:
    f.write(text)
