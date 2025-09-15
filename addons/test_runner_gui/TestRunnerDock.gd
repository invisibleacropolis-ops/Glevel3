extends VBoxContainer
class_name TestRunnerDock

@onready var output_box: TextEdit = $Output
@onready var options: GridContainer = $Options

func _ready() -> void:
    $RunButton.pressed.connect(_on_run_pressed)

func _on_run_pressed() -> void:
    output_box.text = ""
    var args: PackedStringArray = []
    if options.get_node("NoColor").button_pressed:
        args.append("--no-color")
    var out_dir := options.get_node("OutDir").text.strip_edges()
    if out_dir != "":
        args.append_array(["--out-dir", out_dir])
    if options.get_node("NoJson").button_pressed:
        args.append("--no-json")
    if options.get_node("NoXml").button_pressed:
        args.append("--no-xml")
    if options.get_node("Simple").button_pressed:
        args.append("--simple")
    var batch_size := int(options.get_node("BatchSize").value)
    if batch_size > 0:
        args.append_array(["--batch-size", str(batch_size)])
    var slow := int(options.get_node("Slow").value)
    args.append_array(["--slow", str(slow)])
    var retries := int(options.get_node("Retries").value)
    if retries > 0:
        args.append_array(["--retries", str(retries)])
    var tags := options.get_node("Tags").text.strip_edges()
    if tags != "":
        args.append_array(["--tags", tags])
    var skip := options.get_node("Skip").text.strip_edges()
    if skip != "":
        args.append_array(["--skip", skip])
    var pri := options.get_node("Priority").text.strip_edges()
    if pri != "":
        args.append_array(["--priority", pri])
    var owner := options.get_node("Owner").text.strip_edges()
    if owner != "":
        args.append_array(["--owner", owner])

    var exe_path := OS.get_executable_path()
    var cmd_args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tests/Test_runner.gd"]
    cmd_args.append_array(args)
    var output: Array = []
    var code := OS.execute(exe_path, cmd_args, output, true)
    output_box.text = "\n".join(output)
    output_box.append_text("\nExit code: %d" % code)
