using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;

namespace TodoAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ItemsController : ControllerBase
    {
        private static readonly string[] Descriptions = new[]
        {
            "Do Laundry", "Walk the Dog", "Go Grocery Shopping", "Clean my Room", "Wash my Car", "Do the Dishes"
        };

        private readonly ILogger<ItemsController> _logger;

        public ItemsController(ILogger<ItemsController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IEnumerable<TodoItem> Get()
        {
            var rng = new Random();
            return Enumerable.Range(1, 5).Select(index => new TodoItem
            {
                Id = Guid.NewGuid(),
                Description = Descriptions[rng.Next(Descriptions.Length)],
                Completed = false,
                CreatedAt = DateTime.Now.AddDays(index)
            })
            .ToArray();
        }
    }
}
