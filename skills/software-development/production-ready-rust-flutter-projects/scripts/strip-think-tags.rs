/// Strip <think>...</think> reasoning blocks from LLM streaming output.
///
/// Some models (Qwen, DeepSeek-R1) output chain-of-thought reasoning
/// inside <think>...</think> tags. This function removes those blocks
/// from the content stream so only the final answer reaches the UI.
///
/// Works on individual streaming chunks — each chunk may contain a partial
/// tag, but since streaming is character-by-character for these models,
/// the byte comparison is safe for most real-world cases.
/// For stricter handling, accumulate chunks and strip after [DONE].
fn strip_think_tags(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut in_think = false;
    let mut i = 0;
    let bytes = s.as_bytes();
    while i < bytes.len() {
        if !in_think && i + 6 < bytes.len()
            && bytes[i] == b'<' && bytes[i+1] == b't' && bytes[i+2] == b'h'
            && bytes[i+3] == b'i' && bytes[i+4] == b'n' && bytes[i+5] == b'k'
            && bytes[i+6] == b'>'
        {
            in_think = true;
            i += 7;
            continue;
        }
        if in_think && i + 7 < bytes.len()
            && bytes[i] == b'<' && bytes[i+1] == b'/' && bytes[i+2] == b't'
            && bytes[i+3] == b'h' && bytes[i+4] == b'i' && bytes[i+5] == b'n'
            && bytes[i+6] == b'k' && bytes[i+7] == b'>'
        {
            in_think = false;
            i += 8;
            continue;
        }
        if !in_think {
            result.push(bytes[i] as char);
        }
        i += 1;
    }
    result
}
