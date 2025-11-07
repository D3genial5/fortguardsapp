import os
import re

# Lista de pantallas que necesitan BackHandler
screens = [
    "lib/screens/common/about_screen.dart",
    "lib/screens/common/help_center_screen.dart",
    "lib/screens/common/terms_screen.dart",
    "lib/screens/personal/seleccion_accion_screen.dart",
    "lib/screens/propietario/gestionar_solicitudes_screen.dart",
    "lib/screens/propietario/notificaciones_condominio_screen.dart",
    "lib/screens/propietario/notificaciones_prop_screen.dart",
    "lib/screens/propietario/notificaciones_screen.dart",
    "lib/screens/propietario/pago_expensas_screen.dart",
    "lib/screens/propietario/panel_propietario_screen.dart",
    "lib/screens/propietario/reservas_screen.dart",
    "lib/screens/qr/mi_qr_screen.dart",
    "lib/screens/qr/mis_qrs_screen.dart",
    "lib/screens/qr/solicitud_qr_screen.dart",
    "lib/screens/visita/ingreso_casa_screen.dart",
    "lib/screens/visita/qr_casa_screen.dart",
    "lib/screens/visita/seleccion_casa_screen.dart",
    "lib/screens/visita/seleccion_condo.dart"
]

base_path = "d:/work/fortguardsapp/"

for screen_path in screens:
    full_path = os.path.join(base_path, screen_path)
    
    if not os.path.exists(full_path):
        print(f"Archivo no encontrado: {full_path}")
        continue
    
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Verificar si ya tiene BackHandler
    if "BackHandler" in content:
        print(f"Ya tiene BackHandler: {screen_path}")
        continue
    
    # Agregar import si no existe
    if "import '../../widgets/back_handler.dart';" not in content:
        # Buscar el último import y agregar después
        import_pattern = r"(import [^;]+;\n)+"
        match = re.search(import_pattern, content)
        if match:
            end_pos = match.end()
            # Calcular la ruta relativa correcta
            depth = screen_path.count('/') - 1
            back_path = '../' * depth
            import_line = f"import '{back_path}widgets/back_handler.dart';\n"
            content = content[:end_pos] + import_line + content[end_pos:]
    
    # Envolver Scaffold con BackHandler
    # Buscar "return Scaffold(" y reemplazar con "return BackHandler(\n      child: Scaffold("
    scaffold_pattern = r"(\s+)return Scaffold\("
    
    def replace_scaffold(match):
        indent = match.group(1)
        return f"{indent}return BackHandler(\n{indent}  child: Scaffold("
    
    content = re.sub(scaffold_pattern, replace_scaffold, content)
    
    # Agregar paréntesis de cierre
    # Buscar el último ");" antes del final de la clase y agregar "),"
    build_end_pattern = r"(\s+)\);\s*\}\s*(?:\n\s*(?:Widget|void|Future|@override))"
    
    def add_closing_paren(match):
        indent = match.group(1)
        rest = match.group(0)
        # Insertar el paréntesis de cierre antes del último );
        return rest.replace(");", "),\n" + indent + ");", 1)
    
    content = re.sub(build_end_pattern, add_closing_paren, content)
    
    # Guardar el archivo modificado
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Modificado: {screen_path}")

print("¡Proceso completado!")
