import zipfile, xml.etree.ElementTree as ET

z = zipfile.ZipFile(r'c:\Users\soyba\OneDrive\Escritorio\CalmSpace\CalmSpace\Backlog_SaludMental_v2.docx')
xml_content = z.read('word/document.xml')
tree = ET.fromstring(xml_content)
out = [elem.text for elem in tree.iter() if elem.tag.endswith('t') and elem.text]
z.close()

with open(r'c:\Users\soyba\OneDrive\Escritorio\CalmSpace\CalmSpace\backlog_output.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

print("Done - saved to backlog_output.txt")
