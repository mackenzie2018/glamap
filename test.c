// 19:27
#include <expat.h>
#include <stdio.h>
#include <string.h>

#ifdef XML_LARGE_SIZE
#define XML_FMT_INT_MOD "ll"
#else
#define XML_FMT_INT_MOD "l"
#endif

#ifdef XML_UNICODE_WCHAR_T
#define XML_FMT_STR "ls"
#else
#define XML_FMT_STR "s"
#endif

struct parser_data {
  size_t num_nodes;
  size_t num_ways;
  size_t node_refs;
};

static void XMLCALL startElement(void *userData, const XML_Char *name,
                                 const XML_Char **atts) {
  int i;
  struct parser_data *parser_data = (struct parser_data *)userData;
  (void)atts;

  if (strcmp("node", name) == 0) {
    parser_data->num_nodes += 1;
  } else if (strcmp("way", name) == 0) {
    parser_data->num_ways += 1;
  } else if (strcmp("nd", name) == 0) {
    parser_data->node_refs += 1;
  }
}

static void XMLCALL endElement(void *userData, const XML_Char *name) {
  // int *const depthPtr = (int *)userData;
  // (void)name;
  //
  // *depthPtr -= 1;
}

int main(int argc, char **argv) {
  XML_Parser parser = XML_ParserCreate(NULL);
  int done;
  int depth = 0;

  if (argc < 2) {
    fprintf(stderr, "Not enough arguments\n");
    return 1;
  }

  FILE *file = fopen(argv[1], "r");

  if (!parser) {
    fprintf(stderr, "Couldn't allocate memory for parser\n");
    return 1;
  }

  struct parser_data data = {0};
  XML_SetUserData(parser, &data);
  XML_SetElementHandler(parser, startElement, endElement);

  int i = 0;
  do {
    i += 1;
    if (i == 3000000) {
      break;
    }
    if (i % 1000 == 0) {
      printf("nodes: %lu\tways: %lu\trefs: %lu\n", data.num_nodes,
             data.num_ways, data.node_refs);
    }
    void *const buf = XML_GetBuffer(parser, BUFSIZ);
    if (!buf) {
      fprintf(stderr, "Couldn't allocate memory for buffer\n");
      XML_ParserFree(parser);
      return 1;
    }

    const size_t len = fread(buf, 1, BUFSIZ, file);

    if (ferror(stdin)) {
      fprintf(stderr, "Read error\n");
      XML_ParserFree(parser);
      return 1;
    }

    done = feof(stdin);

    if (XML_ParseBuffer(parser, (int)len, done) == XML_STATUS_ERROR) {
      fprintf(stderr,
              "Parse error at line %" XML_FMT_INT_MOD "u:\n%" XML_FMT_STR "\n",
              XML_GetCurrentLineNumber(parser),
              XML_ErrorString(XML_GetErrorCode(parser)));
      XML_ParserFree(parser);
      return 1;
    }
  } while (!done);

  printf("nodes: %lu\tways: %lu\trefs: %lu\n", data.num_nodes, data.num_ways,
         data.node_refs);

  XML_ParserFree(parser);
  return 0;
}
