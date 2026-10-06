param(
    [Parameter(Mandatory=$true)]
    [string]$SourceRoot
)

$ErrorActionPreference = "Stop"

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $s = Get-Content -Raw -LiteralPath $Path
    if ($s.Contains($New)) {
        Write-Host "Already patched: $Label"
        return
    }
    if (-not $s.Contains($Old)) {
        throw "Patch anchor not found for $Label in $Path"
    }
    Set-Content -LiteralPath $Path -Value ($s.Replace($Old, $New)) -Encoding UTF8
    Write-Host "Patched: $Label"
}

$cpp = Join-Path $SourceRoot "src\Gui\DodiSimpleCam.cpp"
$py = Join-Path $SourceRoot "src\Mod\CAM\PathScripts\DodiNativeCam.py"

if (!(Test-Path $cpp)) { throw "Missing DodiSimpleCam.cpp" }
if (!(Test-Path $py)) { throw "Missing DodiNativeCam.py" }

Replace-Exact $cpp @'
#include "Command.h"
'@ @'
#include "Command.h"
#include "Interpreter.h"
#include "Exception.h"
'@ "C++ interpreter includes"

Replace-Exact $cpp @'
bool runDodiPython(const QString& code, QString* error = nullptr)
{
    Gui::Command::runCommand(Gui::Command::App, code.toUtf8().constData());
    if (error) error->clear();
    return true;
}
'@ @'
bool runDodiPython(const QString& code, QString* error = nullptr)
{
    try {
        Base::Interpreter().runString(code.toUtf8().constData());
        if (error) error->clear();
        return true;
    }
    catch (const Base::Exception& exc) {
        if (error) *error = QString::fromUtf8(exc.what());
        Base::Console().error("DODI CAM Python error: {}\n", exc.what());
        return false;
    }
    catch (const std::exception& exc) {
        if (error) *error = QString::fromUtf8(exc.what());
        Base::Console().error("DODI CAM C++ exception: {}\n", exc.what());
        return false;
    }
}
'@ "C++ Python error gate"

Replace-Exact $cpp @'
auto* width = new QDoubleSpinBox; width->setRange(1, 5000); width->setValue(600); width->setSuffix(" mm");
    auto* height = new QDoubleSpinBox; height->setRange(1, 5000); height->setValue(400); height->setSuffix(" mm");
'@ @'
auto* width = new QDoubleSpinBox; width->setRange(1, 5000); width->setValue(550); width->setSuffix(" mm");
    auto* height = new QDoubleSpinBox; height->setRange(1, 5000); height->setValue(550); height->setSuffix(" mm");
    auto* sizePreset = new QComboBox;
    sizePreset->addItem(QStringLiteral("550 x 550 mm"), 550.0);
    sizePreset->addItem(QStringLiteral("750 x 750 mm"), 750.0);
    sizePreset->addItem(QStringLiteral("Custom"), 0.0);
'@ "550/750 presets"

Replace-Exact $cpp @'
auto* safeZ = new QDoubleSpinBox; safeZ->setRange(0.5, 200); safeZ->setValue(5); safeZ->setSuffix(" mm");
    auto* kerf
'@ @'
auto* safeZ = new QDoubleSpinBox; safeZ->setRange(0.5, 200); safeZ->setValue(10); safeZ->setSuffix(" mm");
    auto* throughCut = new QCheckBox(QStringLiteral("Potong tembus (through-cut)"));
    throughCut->setChecked(true);
    auto* breakthrough = new QDoubleSpinBox; breakthrough->setRange(0.0, 5.0); breakthrough->setValue(0.20); breakthrough->setSuffix(" mm");
    auto* kerf
'@ "through-cut controls"

Replace-Exact $cpp @'
form->addRow(QStringLiteral("Lebar media kerja"), width);
    form->addRow(QStringLiteral("Ukuran otomatis"), autoMedia);
'@ @'
form->addRow(QStringLiteral("Lebar media kerja"), width);
    form->addRow(QStringLiteral("Preset ukuran"), sizePreset);
    form->addRow(QStringLiteral("Ukuran otomatis"), autoMedia);
'@ "preset row"

Replace-Exact $cpp @'
form->addRow(QStringLiteral("Safe Z"), safeZ);
    form->addRow(QStringLiteral("Kerf / Offset tambahan"), kerf);
'@ @'
form->addRow(QStringLiteral("Safe Z"), safeZ);
    form->addRow(QStringLiteral("Mode cutting"), throughCut);
    form->addRow(QStringLiteral("Allowance tembus"), breakthrough);
    form->addRow(QStringLiteral("Kerf / Offset tambahan"), kerf);
'@ "through-cut rows"

Replace-Exact $cpp @'
QImage prepareImage(const QImage& input, int maxWidth = 900)
'@ @'
QImage prepareImage(const QImage& input, int maxWidth = 1200)
'@ "trace resolution"

Replace-Exact $cpp @'
QObject::connect(autoMedia, &QPushButton::clicked, &dlg, [&]() {
'@ @'
QObject::connect(sizePreset, QOverload<int>::of(&QComboBox::currentIndexChanged), &dlg, [&](int index) {
        const double v = sizePreset->itemData(index).toDouble();
        if (v > 0.0) {
            width->setValue(v);
            height->setValue(v);
        }
    });

    QObject::connect(autoMedia, &QPushButton::clicked, &dlg, [&]() {
'@ "preset handler"

Replace-Exact $cpp @'
        width->setValue(600);
        height->setValue(600.0 * double(prepared.height()) / double(qMax(1, prepared.width())));
'@ @'
        height->setValue(width->value() * double(prepared.height()) / double(qMax(1, prepared.width())));
        sizePreset->setCurrentIndex(2);
'@ "auto media ratio"

Replace-Exact $cpp @'
    out << "<g fill=\"none\" stroke=\"black\" stroke-width=\"0.1\">\n";
'@ @'
    out << "<g fill=\"black\" stroke=\"none\" fill-rule=\"evenodd\" data-dodi-role=\"CUT\">\n";
'@ "black cut-region SVG"

Replace-Exact $cpp @'
        const QString cmd = QStringLiteral("import PathScripts.DodiNativeCam as D; D.import_svg_geometry(%1)")
            .arg(pythonQuote(svgPath));
        runDodiPython(cmd);
        makeJob->setEnabled(true);
'@ @'
        const QString cmd = QStringLiteral("import PathScripts.DodiNativeCam as D; D.import_svg_geometry(%1)")
            .arg(pythonQuote(svgPath));
        QString error;
        if (!runDodiPython(cmd, &error)) {
            QMessageBox::critical(&dlg, QStringLiteral("DODI CAM"),
                                  QStringLiteral("SVG -> Geometry gagal.\n\n%1").arg(error));
            return;
        }
        makeJob->setEnabled(true);
'@ "SVG error gate"

Replace-Exact $cpp @'
        QString cmd = QStringLiteral(
            "import PathScripts.DodiNativeCam as D; D.create_native_job(%1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11, %12, %13, %14, %15, %16, %17, %18)")
'@ @'
        const double effectiveDepth = (throughCut->isChecked() && operation->currentData().toString() != QStringLiteral("Engrave"))
            ? thickness->value() + breakthrough->value()
            : depth->value();
        QString cmd = QStringLiteral(
            "import PathScripts.DodiNativeCam as D; D.create_native_job(%1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11, %12, %13, %14, %15, %16, %17, %18)")
'@ "effective depth"

Replace-Exact $cpp @'
            .arg(depth->value(), 0, 'f', 6)
'@ @'
            .arg(effectiveDepth, 0, 'f', 6)
'@ "depth argument"

Replace-Exact $cpp @'
        runDodiPython(cmd);
        makeJob->setEnabled(false);
'@ @'
        QString error;
        if (!runDodiPython(cmd, &error)) {
            QMessageBox::critical(&dlg, QStringLiteral("DODI CAM"),
                                  QStringLiteral("Native Job gagal dibuat.\n\n%1").arg(error));
            return;
        }
        makeJob->setEnabled(false);
'@ "native job error gate"

Replace-Exact $cpp @'
        runDodiPython(QStringLiteral("import PathScripts.DodiNativeCam as D; D.prepare_simulation()"));
        status->setText(QStringLiteral("Native CAM Simulator dibuka. Periksa Toolpath dan stock sebelum menjalankan mesin."));
'@ @'
        QString error;
        if (!runDodiPython(QStringLiteral("import PathScripts.DodiNativeCam as D; D.prepare_simulation()"), &error)) {
            QMessageBox::warning(&dlg, QStringLiteral("DODI CAM"),
                                 QStringLiteral("Simulator gagal dibuka.\n\n%1").arg(error));
            return;
        }
        status->setText(QStringLiteral("Native CAM Simulator dibuka. Periksa Toolpath dan stock sebelum menjalankan mesin."));
'@ "simulation error gate"

Replace-Exact $cpp @'
        runDodiPython(QStringLiteral("import PathScripts.DodiNativeCam as D; D.post_latest_job(%1, %2)")
                          .arg(pythonQuote(out)).arg(operation->currentData().toString() == "Plasma" ? "True" : "False"));
        progress->setValue(100);
'@ @'
        QString error;
        if (!runDodiPython(QStringLiteral("import PathScripts.DodiNativeCam as D; D.post_latest_job(%1, %2)")
                           .arg(pythonQuote(out)).arg(operation->currentData().toString() == "Plasma" ? "True" : "False"), &error)) {
            QMessageBox::critical(&dlg, QStringLiteral("DODI CAM"),
                                  QStringLiteral("G-code gagal dibuat.\n\n%1").arg(error));
            QFile::remove(out);
            return;
        }
        progress->setValue(100);
'@ "G-code error gate"

$pytext = Get-Content -Raw -LiteralPath $py
if (-not $pytext.Contains("_validate_geometry")) {
    $helper = @'
def _validate_geometry(geo, tool_diameter):
    """Validate imported SVG edges before creating a native CAM operation."""
    edges = list(getattr(geo.Shape, "Edges", []))
    if not edges:
        raise RuntimeError("SVG tidak memiliki edge CNC.")
    zero = 0
    for edge in edges:
        try:
            if edge.Length <= 1e-7:
                zero += 1
        except Exception:
            pass
    if zero:
        raise RuntimeError(f"Geometry memiliki {zero} edge dengan panjang nol.")
    if float(tool_diameter) <= 0:
        raise RuntimeError("Diameter tool harus lebih besar dari 0 mm.")
    return len(edges)


'@
    $marker = 'def create_native_job(svg_path, work_w, work_h, thickness, operation, tool_diameter,'
    if (-not $pytext.Contains($marker)) { throw "Python create_native_job anchor missing" }
    $pytext = $pytext.Replace($marker, $helper + $marker)
    $nl = [Environment]::NewLine
    $pytext = $pytext.Replace("    geo = _find_svg_geometry(doc)" + $nl + $nl + "    # Make a real sheet model", "    geo = _find_svg_geometry(doc)" + $nl + "    _validate_geometry(geo, tool_diameter)" + $nl + $nl + "    # Make a real sheet model")
    $pytext = $pytext.Replace("    job.Label = 'DODI Job • Native CAM'", "    job.Label = f'DODI Job • Native CAM • {float(work_w):g}x{float(work_h):g} mm'")
    Set-Content -LiteralPath $py -Value $pytext -Encoding UTF8
    Write-Host "Patched: native geometry validation"
} else {
    Write-Host "Already patched: native geometry validation"
}

Write-Host "DODI V2.3 source patch completed successfully."
